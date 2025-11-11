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
    @days_left = @check_in.days_left
    @active_tab = extract_active_tab
    @stage = @check_in.current_stage
    @seconds_until_midnight = seconds_until_midnight
    render "advent/index", locals: {
      main_locals: main_panel_locals,
      rewards_locals: rewards_panel_locals
    }
  end

  def check_in
    @check_in.complete_part1
    send_check_in_email
    redirect_to advent_path
  end

  def reset_check_in
    @check_in.reset_part1
    redirect_to advent_path
  end

  def draw_voucher
    award = @reward.draw!
    send_voucher_drawn_email(award)
    flash[:voucher_award] = award.title
    redirect_to_wah
  rescue Adapter::AdventCalendar::NoEligibleDrawsError
    next_goal = @reward.next_milestone
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
      flash[:notice] = "Voucher redeemed. Please allow a few second for the request to be processed 😙"
      send_voucher_redeemed_email(voucher)
    end

    redirect_to_wah
  end

  def solve_puzzle
    ok_result = { status: "ok", redirect_to: advent_path(tab: "main") }
    if @prompt.puzzle_format == :button
      @check_in.complete_part2!
      render json: ok_result
      return
    end

    attempt = params[:puzzle_answer].to_s
    @check_in.record_puzzle_attempt(attempt)
    if @prompt.part2_solved?(attempt)
      @check_in.complete_part2!
      send_puzzle_attempt_email(attempt:, solved: true)
      render json: ok_result
    else
      send_puzzle_attempt_email(attempt:, solved: false)
      render json: {
        status: "error",
        message: "Need my help? 😗"
      }, status: :ok
    end
  end

  private

  def set_calendar
    @today = requested_calendar_day
    @check_in = Adapter::AdventCalendar::CheckIn.for(@today)
    @reward = Adapter::AdventCalendar::Reward.for(@today)
    @prompt = Adapter::AdventCalendar::Prompt.for(@today)
  end

  def seconds_until_midnight
    now = Time.zone.now
    midnight_tomorrow = now.tomorrow.beginning_of_day
    [(midnight_tomorrow - now).to_i, 0].max
  end

  def extract_active_tab
    requested = params[:tab].to_s
    return requested if %w[main wah faq].include?(requested)

    "main"
  end

  def redirect_to_wah
    redirect_to advent_path(tab: "wah"), status: :see_other
  end

  def send_check_in_email
    return unless Rails.env.production?

    AdventNotifierMailer.check_in(day: @today).deliver_now
  end

  def send_puzzle_attempt_email(attempt:, solved: false)
    return unless Rails.env.production?

    AdventNotifierMailer.puzzle_attempt(day: @today, attempt: attempt, solved: solved).deliver_now
  end

  def send_voucher_drawn_email(award)
    return unless Rails.env.production?

    AdventNotifierMailer.voucher_drawn(
      day: @today,
      title: award.title,
      details: award.details
    ).deliver_now
  end

  def send_voucher_redeemed_email(voucher)
    return unless Rails.env.production?

    AdventNotifierMailer.voucher_redeemed(
      day: @today,
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

    Adapter::AdventCalendar::CheckIn.new(
      day: target_day,
      store: Adapter::AdventCalendar::Store.instance
    ).reset_part1

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

  def attempt_redeem_voucher(voucher_id)
    @reward.redeem!(voucher_id)
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
    details = @reward.vouchers.find { |entry| (entry[:id] || entry["id"]).to_s == voucher_id }
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

  def main_panel_locals
    story_lines = @prompt.story_lines
    story_lines = story_paragraphs_for(@today) if story_lines.empty?

    {
      part1_prompts: @prompt.part1_prompts,
      part2_prompts: @prompt.part2_prompts,
      done_prompts: @prompt.done_prompts,
      puzzle_format: @prompt.puzzle_format,
      puzzle_prompt: @prompt.puzzle_prompt,
      story: story_lines
    }
  end

  def rewards_panel_locals
    voucher_message = flash[:notice].presence || flash[:alert]
    {
      total_stars: @reward.total_stars,
      total_check_ins: @check_in.total_check_ins,
      next_milestone: @reward.next_milestone,
      stars_until_next: @reward.stars_until_next_milestone,
      can_draw: @reward.can_draw?,
      latest_voucher_title: flash[:voucher_award],
      voucher_alert: voucher_message,
      vouchers: @reward.vouchers,
      voucher_redeemed: flash[:voucher_redeemed].present?
    }
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
