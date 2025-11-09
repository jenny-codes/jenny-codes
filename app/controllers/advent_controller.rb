# typed: false
# frozen_string_literal: true

class AdventController < ApplicationController
  ADVENT_PASSWORD = "cremebrulee"
  STORY_FILE = Rails.root.join("lib/data/advent_story.yml")

  before_action :require_advent_password
  before_action :store_inspect_param
  before_action :maybe_reset_day, only: :index
  before_action :set_calendar
  layout "advent"

  def index
    @days_left = @calendar.days_left
    assign_star_stats
    assign_voucher_stats
    @active_tab = extract_active_tab
    assign_puzzle_state
    @story_state = story_state
    @seconds_until_midnight = seconds_until_midnight
    render "advent/index", locals: layout_locals
  end

  def check_in
    already_checked = @calendar.checked_in?
    @calendar.check_in
    send_check_in_email unless already_checked
    redirect_to advent_path
  end

  def reset_check_in
    @calendar.reset_check_in
    redirect_to advent_path
  end

  def draw_voucher
    award = @calendar.draw_voucher!
    send_voucher_drawn_email(award)
    flash[:voucher_award] = award.to_h
    redirect_to_wah
  rescue Adapter::AdventCalendar::NoEligibleDrawsError
    next_goal = @calendar.next_milestone
    flash[:alert] = if next_goal
                      "Next draw unlocks at #{next_goal} stars. Keep checking in!"
                    else
                      "You have already unlocked every draw milestone."
                    end
    redirect_to_wah
  end

  def redeem_voucher
    voucher_id = params[:voucher_id].to_s.strip
    return redirect_with_alert("Please select a voucher to redeem.") if voucher_id.blank?

    voucher = attempt_redeem_voucher(voucher_id)
    if voucher
      flash[:voucher_redeemed] = true
      flash[:alert] = "Voucher redeemed. Please allow a few second for the request to be processed 😙"
      send_voucher_redeemed_email(voucher)
    end

    redirect_to_wah
  end

  def solve_puzzle
    attempt_param = params[:puzzle_answer]
    attempt = attempt_param.to_s
    persist_flash = !request.format.json?

    result = if params[:auto_complete].present?
               auto_complete_puzzle_result
             elsif attempt_param.nil? || attempt.strip.empty?
               handle_blank_puzzle_attempt(attempt, persist_flash: persist_flash)
             else
               apply_puzzle_attempt(attempt, persist_flash: persist_flash)
             end

    send_puzzle_attempt_email(attempt: result[:attempt], solved: result[:solved])

    respond_to do |format|
      format.html { redirect_to advent_path(tab: "main"), status: :see_other }
      format.json { render_puzzle_attempt_json(result) }
    end
  end

  private

  DAILY_TEMPLATE_DIR = "advent/panels/days"
  DEFAULT_DAILY_TEMPLATE = "20251108"

  def set_calendar
    @today = requested_calendar_day
    @calendar = Adapter::AdventCalendar.on(@today)
  end

  def assign_star_stats
    @star_count = @calendar.total_stars
    @total_check_ins = @calendar.total_check_ins
    @draws_available = @calendar.draws_available
    @next_milestone = @calendar.next_milestone
    @stars_until_next_milestone = @calendar.stars_until_next_milestone
  end

  def assign_voucher_stats
    @vouchers = @calendar.vouchers.sort_by do |voucher|
      voucher[:redeemed] ? 1 : 0
    end
    @voucher_milestones = @calendar.voucher_milestones
  end

  def assign_puzzle_state
    if @calendar.puzzle_completed?
      session[:advent_puzzle_completed] = true
      flash.delete(:advent_puzzle_attempt)
      flash.delete(:advent_puzzle_error)
    end

    @puzzle_completed = session[:advent_puzzle_completed] == true
    @puzzle_attempt = flash[:advent_puzzle_attempt]
    @puzzle_error = flash[:advent_puzzle_error]
  end

  def mark_puzzle_completed
    session[:advent_puzzle_completed] = true
    flash.delete(:advent_puzzle_attempt)
    flash.delete(:advent_puzzle_error)
  end

  def seconds_until_midnight
    now = Time.zone.now
    midnight_tomorrow = now.tomorrow.beginning_of_day
    [(midnight_tomorrow - now).to_i, 0].max
  end

  def layout_locals
    daily_partial = daily_template_partial
    stage = story_state

    {
      main_partial: daily_partial,
      main_locals: {
        stage: stage,
        primary_action: (stage == :part1 ? check_in_button : nil),
        story_texts: story_paragraphs_for(@today)
      }.compact
    }
  end

  def extract_active_tab
    requested = params[:tab].to_s
    return requested if %w[main wah faq].include?(requested)

    "main"
  end

  def redirect_to_wah
    redirect_to advent_path(tab: "wah"), status: :see_other
  end

  def daily_template_partial
    "#{DAILY_TEMPLATE_DIR}/#{daily_template_name}"
  end

  def daily_template_name
    @daily_template_name ||= begin
      preferred = @today.strftime("%Y%m%d")
      if template_exists_for?(preferred)
        preferred
      else
        available_daily_templates.first || DEFAULT_DAILY_TEMPLATE
      end
    end
  end

  def template_exists_for?(name)
    lookup_context.exists?("#{DAILY_TEMPLATE_DIR}/#{name}", [], true)
  end

  def available_daily_templates
    Dir.glob(Rails.root.join("app", "views", DAILY_TEMPLATE_DIR, "_*.html.*"))
       .map { |path| File.basename(path).split(".").first.delete_prefix("_") }
       .sort
  end

  def story_state
    return :completed if @calendar.puzzle_completed?
    return :part2 if @calendar.checked_in?

    :part1
  end

  def check_in_button
    view_context.button_to(
      "Check in",
      advent_check_in_path,
      method: :post,
      class: "advent-button",
      data: { advent_check_in: true }
    )
  end

  def send_check_in_email
    AdventNotifierMailer.check_in(day: @calendar.day).deliver_now
  end

  def apply_puzzle_attempt(attempt, persist_flash: true)
    if @calendar.attempt_puzzle!(attempt)
      mark_puzzle_completed
      { solved: true, message: nil, attempt: attempt }
    else
      error_message = puzzle_error_message
      remember_puzzle_attempt(attempt, persist_flash: persist_flash, message: error_message)
      { solved: false, message: error_message, attempt: attempt }
    end
  end

  def render_puzzle_attempt_json(result)
    if result[:solved]
      render json: { status: "ok", redirect_to: advent_path(tab: "main") }
    else
      render json: {
        status: "error",
        message: result[:message] || puzzle_error_message,
        attempt: result[:attempt]
      }, status: :ok
    end
  end

  def remember_puzzle_attempt(attempt, persist_flash: true, message: puzzle_error_message)
    return unless persist_flash

    flash[:advent_puzzle_attempt] = attempt
    flash[:advent_puzzle_error] = message
  end

  def puzzle_error_message
    "That is not correct. Try again?"
  end

  def puzzle_blank_message
    "Please enter an answer before submitting."
  end

  def send_puzzle_attempt_email(attempt:, solved: false)
    AdventNotifierMailer.puzzle_attempt(day: @calendar.day, attempt: attempt, solved: solved).deliver_now
  end

  def send_voucher_drawn_email(award)
    AdventNotifierMailer.voucher_drawn(
      day: @calendar.day,
      title: award.title,
      details: award.details
    ).deliver_now
  end

  def send_voucher_redeemed_email(voucher)
    AdventNotifierMailer.voucher_redeemed(
      day: @calendar.day,
      title: voucher.title,
      details: voucher.details
    ).deliver_now
  end

  def require_advent_password
    authenticate_or_request_with_http_basic("Advent Calendar") do |_username, password|
      ActiveSupport::SecurityUtils.secure_compare(password.to_s, ADVENT_PASSWORD)
    end
  end

  def maybe_reset_day
    target_day = parse_calendar_day(params[:reset])
    return unless target_day

    Adapter::AdventCalendar.on(target_day).reset_check_in

    remaining = request.query_parameters.except("reset")
    redirect_to advent_path(remaining.symbolize_keys) and return
  end

  def requested_calendar_day
    token = params[:inspect].presence || session[:advent_inspect]
    parse_calendar_day(token) || Time.zone.today
  end

  def parse_calendar_day(value)
    return if value.blank?

    token = value.to_s.strip
    return if token.empty?

    base = Date.strptime(token, "%m%d")
    base.change(year: Adapter::AdventCalendar::END_DATE.year)
  rescue ArgumentError
    nil
  end

  def handle_blank_puzzle_attempt(attempt, persist_flash: true)
    message = puzzle_blank_message
    remember_puzzle_attempt(attempt, persist_flash: persist_flash, message: message)
    { solved: false, message: message, attempt: attempt }
  end

  def auto_complete_puzzle_result
    if @calendar.complete_puzzle!
      mark_puzzle_completed
      { solved: true, message: nil, attempt: "[auto]" }
    else
      { solved: false, message: puzzle_error_message, attempt: "[auto]" }
    end
  end

  def attempt_redeem_voucher(voucher_id)
    @calendar.redeem_voucher!(voucher_id)
  rescue Adapter::AdventCalendar::VoucherNotRedeemableError
    assign_not_redeemable_flash(voucher_id)
    nil
  rescue Adapter::AdventCalendar::VoucherAlreadyRedeemedError
    flash[:alert] = "This voucher has already been redeemed."
    nil
  rescue Adapter::AdventCalendar::VoucherNotFoundError
    flash[:alert] = "We couldn't find that voucher."
    nil
  end

  def assign_not_redeemable_flash(voucher_id)
    details = @calendar.vouchers.find { |entry| (entry[:id] || entry["id"]).to_s == voucher_id }
    redeemable_at = details && (details[:redeemable_at] || details["redeemable_at"])
    formatted = format_redeemable_date(redeemable_at)
    flash[:alert] =
      formatted ? "This voucher is redeemable on #{formatted}. Hang tight!" : "This voucher is not redeemable yet."
  end

  def redirect_with_alert(message)
    flash[:alert] = message
    redirect_to_wah
  end

  def default_url_options
    super.merge(inspect: session[:advent_inspect]).compact
  end

  def format_redeemable_date(value)
    return if value.blank?

    date = Date.iso8601(value.to_s)
    date.strftime("%b %d, %Y")
  rescue ArgumentError
    nil
  end

  def store_inspect_param
    return unless params.key?(:inspect)

    session[:advent_inspect] = params[:inspect].presence
  end

  def story_catalog
    @story_catalog ||= YAML.safe_load_file(STORY_FILE, permitted_classes: [], aliases: false) || {}
  end

  def story_paragraphs_for(date)
    raw = story_catalog[date.strftime("%Y%m%d")]
    return [] unless raw.present?

    raw.to_s.split(/\r?\n\r?\n+/).map do |chunk|
      chunk.lines.map(&:strip).join(" ").squeeze(" ").strip
    end.reject(&:blank?)
  end
end
