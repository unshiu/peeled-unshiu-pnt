#= Point管理システム
#
#== Summary
# ポイント増減処理用のfiterを提供する
# もしaction内の処理によりポイント増減処理を取り消したい場合は例外として 
# params[:pnt_request_cancel] に　trueを設定する
# 商品の購入などfilterでは制御できないものはgiveをつかって個別に処理する
# 
# example)
#
# フィルターを有効化
# class ApplicationController < ActionController::Base
#  include PntPointSystem
#  around_filter :pnt_target_filter
# end 
# 
# 処理途中で問題があったのでポイント付与処理をやめたい場合
# def create
#   @blog = Blog.new(params[:blog])
#   if @blog.save
#     flash[:notice] = "create!"
#     redirect :show, :id => @blog.id
#   else    
#     params[:pnt_request_cancel] = true
#     redirect :list
#   end
# end
#
module PntPointSystemModule
  
  class << self
    def included(base)
      base.extend(ClassMethods)
      base.class_eval do
      end
    end
  end
  
  def pnt_target_filter
    logger.debug "controller_name #{controller_name}: action_name #{action_name}"
    yield
    
    if !params[:pnt_request_cancel].nil? || params[:pnt_request_cancel]
      logger.info "pnt request cancel #{controller_name}: action_name #{action_name}"
    else
      exec_point_process 
    end
  end
  
private

  def exec_point_process
    base_user_id = request.session[:base_user]
    return if base_user_id.nil? # 対象はログインユーザのみ

    pnt_filters = PntFilter.find_target_filters(controller_name, action_name)
    return if pnt_filters.empty?

    PntHistory.transaction do
      pnt_filters.each do |tmp_filter|
        pnt_filter = PntFilter.find(tmp_filter.id)
        if pnt_filter.use_lock?
          next if PntFilter.lock_if_active(pnt_filter.id, pnt_filter.point).nil?
        end

        logger.info "pnt_filer, :#{pnt_filter.id}, point: #{pnt_filter.point}, user_id: #{base_user_id}"

        point = PntPoint.find_base_user_point(pnt_filter.pnt_master_id, base_user_id)
        unless point
          point = PntPoint.new
          point.pnt_master_id = pnt_filter.pnt_master_id
          point.base_user_id = base_user_id
          point.point = 0
        end

        # 回数制限チェック
        if !pnt_filter.rule_count.blank? && pnt_filter.rule_count > 0
          # 回数制限があれば制限範囲内の履歴をチェック
          if !pnt_filter.rule_day.blank? && pnt_filter.rule_day > 0
            # 範囲日数がある
            begin_date = Date.today - (pnt_filter.rule_day - 1) # たとえば、1日制限なら、今日。2日制限なら昨日（の0時）
            histories = point.pnt_histories.find(:all, :conditions => ['pnt_filter_id = ? and created_at >= ?', pnt_filter.id, begin_date])
          else
            # 回数のみの制限
            histories = point.pnt_histories.find(:all, :conditions => ['pnt_filter_id = ?', pnt_filter.id])
          end

          if histories.size >= pnt_filter.rule_count
            # 制限回数を超えていればスキップ
            next
          end
        end

        # ポイント配布制限チェック
        if pnt_filter.has_limit?
          if pnt_filter.stock < pnt_filter.point
            pnt_filter.save!
            next
          else
            # 残量の減少
            pnt_filter.stock -= pnt_filter.point
            pnt_filter.save!
          end
        end

        point.point += pnt_filter.point
        point.save!

        pnt_history = PntHistory.new
        pnt_history.pnt_point_id = point.id
        pnt_history.difference = pnt_filter.point
        pnt_history.message = pnt_filter.summary
        pnt_history.pnt_filter_id = pnt_filter.id
        pnt_history.amount = point.point
        pnt_history.save!

        logger.info "-> done"
      end
    end
  rescue => e
    logger.error "exec_point_process!: #{e}"
  end
    
  module ClassMethods
    
    # 特定のポイントマスタID(pnt_master_id)のポイントをユーザID(base_user_id)に配布する。
    # ポイントはマイナス値も指定可能だが0ポイント以下にはできない。事前チェックが必要なら個別に行うこと。
    # 
    # _param1_:: base_user_id 必須
    # _param2_:: pnt_master_id　必須
    # _param3_:: point　必須
    # _param3_:: message　ポイント履歴用　必須
    def pointregister(base_user_id, pnt_master_id, point, message)
      
      PntHistory.transaction do
        pnt_point = PntPoint.find_base_user_point(pnt_master_id, base_user_id)
        unless pnt_point
          pnt_point = PntPoint.new
          pnt_point.pnt_master_id = pnt_master_id
          pnt_point.base_user_id = base_user_id
          pnt_point.point = 0
        end
        
        pnt_point.point += point
        pnt_point.save!

        pnt_history = PntHistory.new
        pnt_history.pnt_point_id = pnt_point.id
        pnt_history.difference = point
        pnt_history.message = message
        pnt_history.amount = pnt_point.point
        pnt_history.save!

      end
    rescue => e
      logger.error "exec_point_process!: #{e}"
    end
  end
  

end
  