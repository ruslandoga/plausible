defmodule PlausibleWeb.Email do
  use Plausible
  use Bamboo.Phoenix, view: PlausibleWeb.EmailView
  import Bamboo.PostmarkHelper

  def mailer_email_from do
    Application.get_env(:plausible, :mailer_email)
  end

  def activation_email(user, code) do
    priority_email()
    |> to(user)
    |> tag("activation-email")
    |> subject("#{code} is your Plausible email verification code")
    |> render(:activation_email, user: user, code: code)
  end

  def welcome_email(user) do
    base_email()
    |> to(user)
    |> tag("welcome-email")
    |> subject("Welcome to Plausible")
    |> render(:welcome_email, user: user)
  end

  def create_site_email(user) do
    base_email()
    |> to(user)
    |> tag("create-site-email")
    |> subject("Your Plausible setup: Add your website details")
    |> render(:create_site_email, user: user)
  end

  def site_setup_help(user, site) do
    base_email()
    |> to(user)
    |> tag("help-email")
    |> subject("Your Plausible setup: Waiting for the first page views")
    |> render(:site_setup_help_email,
      user: user,
      site: site
    )
  end

  def site_setup_success(user, site) do
    base_email()
    |> to(user)
    |> tag("setup-success-email")
    |> subject("Plausible is now tracking your website stats")
    |> render(:site_setup_success_email,
      user: user,
      site: site
    )
  end

  def check_stats_email(user) do
    base_email()
    |> to(user)
    |> tag("check-stats-email")
    |> subject("Check your Plausible website stats")
    |> render(:check_stats_email, user: user)
  end

  def password_reset_email(email, reset_link) do
    priority_email(%{layout: nil})
    |> to(email)
    |> tag("password-reset-email")
    |> subject("Plausible password reset")
    |> render(:password_reset_email, reset_link: reset_link)
  end

  def two_factor_enabled_email(user) do
    priority_email()
    |> to(user)
    |> tag("two-factor-enabled-email")
    |> subject("Plausible Two-Factor Authentication enabled")
    |> render(:two_factor_enabled_email, user: user)
  end

  def two_factor_disabled_email(user) do
    priority_email()
    |> to(user)
    |> tag("two-factor-disabled-email")
    |> subject("Plausible Two-Factor Authentication disabled")
    |> render(:two_factor_disabled_email, user: user)
  end

  def trial_one_week_reminder(user) do
    base_email()
    |> to(user)
    |> tag("trial-one-week-reminder")
    |> subject("Your Plausible trial expires next week")
    |> render(:trial_one_week_reminder, user: user)
  end

  def trial_upgrade_email(user, day, usage) do
    suggested_plan = Plausible.Billing.Plans.suggest(user, usage.total)

    base_email()
    |> to(user)
    |> tag("trial-upgrade-email")
    |> subject("Your Plausible trial ends #{day}")
    |> render(:trial_upgrade_email,
      user: user,
      day: day,
      custom_events: usage.custom_events,
      usage: usage.total,
      suggested_plan: suggested_plan
    )
  end

  def trial_over_email(user) do
    base_email()
    |> to(user)
    |> tag("trial-over-email")
    |> subject("Your Plausible trial has ended")
    |> render(:trial_over_email,
      user: user,
      extra_offset: Plausible.Auth.User.trial_accept_traffic_until_offset_days()
    )
  end

  def stats_report(email, assigns) do
    base_email(%{layout: nil})
    |> to(email)
    |> tag("#{assigns.type}-report")
    |> subject("#{assigns.name} report for #{assigns.site.domain}")
    |> html_body(PlausibleWeb.MJML.StatsReport.render(assigns))
  end

  def spike_notification(email, site, current_visitors, sources, dashboard_link) do
    base_email()
    |> to(email)
    |> tag("spike-notification")
    |> subject("Traffic Spike on #{site.domain}")
    |> render(:spike_notification, %{
      site: site,
      current_visitors: current_visitors,
      sources: sources,
      link: dashboard_link
    })
  end

  def over_limit_email(user, usage, suggested_plan) do
    priority_email()
    |> to(user)
    |> tag("over-limit")
    |> subject("[Action required] You have outgrown your Plausible subscription tier")
    |> render(:over_limit, %{
      user: user,
      usage: usage,
      suggested_plan: suggested_plan
    })
  end

  def enterprise_over_limit_internal_email(user, pageview_usage, site_usage, site_allowance) do
    base_email(%{layout: nil})
    |> to("enterprise@plausible.io")
    |> tag("enterprise-over-limit")
    |> subject("#{user.email} has outgrown their enterprise plan")
    |> render(:enterprise_over_limit_internal, %{
      user: user,
      pageview_usage: pageview_usage,
      site_usage: site_usage,
      site_allowance: site_allowance
    })
  end

  def dashboard_locked(user, usage, suggested_plan) do
    priority_email()
    |> to(user)
    |> tag("dashboard-locked")
    |> subject("[Action required] Your Plausible dashboard is now locked")
    |> render(:dashboard_locked, %{
      user: user,
      usage: usage,
      suggested_plan: suggested_plan
    })
  end

  def yearly_renewal_notification(user) do
    date = Timex.format!(user.subscription.next_bill_date, "{Mfull} {D}, {YYYY}")

    priority_email()
    |> to(user)
    |> tag("yearly-renewal")
    |> subject("Your Plausible subscription is up for renewal")
    |> render(:yearly_renewal_notification, %{
      user: user,
      date: date,
      next_bill_amount: user.subscription.next_bill_amount,
      currency: user.subscription.currency_code
    })
  end

  def yearly_expiration_notification(user) do
    next_bill_date = Timex.format!(user.subscription.next_bill_date, "{Mfull} {D}, {YYYY}")

    accept_traffic_until =
      user
      |> Plausible.Users.accept_traffic_until()
      |> Timex.format!("{Mfull} {D}, {YYYY}")

    priority_email()
    |> to(user)
    |> tag("yearly-expiration")
    |> subject("Your Plausible subscription is about to expire")
    |> render(:yearly_expiration_notification, %{
      user: user,
      next_bill_date: next_bill_date,
      accept_traffic_until: accept_traffic_until
    })
  end

  def cancellation_email(user) do
    base_email()
    |> to(user.email)
    |> tag("cancelled-email")
    |> subject("Mind sharing your thoughts on Plausible?")
    |> render(:cancellation_email, user: user)
  end

  def new_user_invitation(invitation) do
    priority_email()
    |> to(invitation.email)
    |> tag("new-user-invitation")
    |> subject("[#{Plausible.product_name()}] You've been invited to #{invitation.site.domain}")
    |> render(:new_user_invitation,
      invitation: invitation
    )
  end

  def existing_user_invitation(invitation) do
    priority_email()
    |> to(invitation.email)
    |> tag("existing-user-invitation")
    |> subject("[#{Plausible.product_name()}] You've been invited to #{invitation.site.domain}")
    |> render(:existing_user_invitation,
      invitation: invitation
    )
  end

  def ownership_transfer_request(invitation, new_owner_account) do
    priority_email()
    |> to(invitation.email)
    |> tag("ownership-transfer-request")
    |> subject(
      "[#{Plausible.product_name()}] Request to transfer ownership of #{invitation.site.domain}"
    )
    |> render(:ownership_transfer_request,
      invitation: invitation,
      new_owner_account: new_owner_account
    )
  end

  def invitation_accepted(invitation) do
    priority_email()
    |> to(invitation.inviter.email)
    |> tag("invitation-accepted")
    |> subject(
      "[#{Plausible.product_name()}] #{invitation.email} accepted your invitation to #{invitation.site.domain}"
    )
    |> render(:invitation_accepted,
      user: invitation.inviter,
      invitation: invitation
    )
  end

  def invitation_rejected(invitation) do
    priority_email()
    |> to(invitation.inviter.email)
    |> tag("invitation-rejected")
    |> subject(
      "[#{Plausible.product_name()}] #{invitation.email} rejected your invitation to #{invitation.site.domain}"
    )
    |> render(:invitation_rejected,
      user: invitation.inviter,
      invitation: invitation
    )
  end

  def ownership_transfer_accepted(invitation) do
    priority_email()
    |> to(invitation.inviter.email)
    |> tag("ownership-transfer-accepted")
    |> subject(
      "[#{Plausible.product_name()}] #{invitation.email} accepted the ownership transfer of #{invitation.site.domain}"
    )
    |> render(:ownership_transfer_accepted,
      user: invitation.inviter,
      invitation: invitation
    )
  end

  def ownership_transfer_rejected(invitation) do
    priority_email()
    |> to(invitation.inviter.email)
    |> tag("ownership-transfer-rejected")
    |> subject(
      "[#{Plausible.product_name()}] #{invitation.email} rejected the ownership transfer of #{invitation.site.domain}"
    )
    |> render(:ownership_transfer_rejected,
      user: invitation.inviter,
      invitation: invitation
    )
  end

  def site_member_removed(membership) do
    priority_email()
    |> to(membership.user.email)
    |> tag("site-member-removed")
    |> subject(
      "[#{Plausible.product_name()}] Your access to #{membership.site.domain} has been revoked"
    )
    |> render(:site_member_removed,
      user: membership.user,
      membership: membership
    )
  end

  def import_success(site_import, user) do
    import_api = Plausible.Imported.ImportSources.by_name(site_import.source)
    label = import_api.label()

    priority_email()
    |> to(user)
    |> tag("import-success-email")
    |> subject("#{label} data imported for #{site_import.site.domain}")
    |> render(import_api.email_template(), %{
      site_import: site_import,
      label: label,
      link: PlausibleWeb.Endpoint.url() <> "/" <> URI.encode_www_form(site_import.site.domain),
      user: user,
      success: true
    })
  end

  def import_failure(site_import, user) do
    import_api = Plausible.Imported.ImportSources.by_name(site_import.source)
    label = import_api.label()

    priority_email()
    |> to(user)
    |> tag("import-failure-email")
    |> subject("#{label} import failed for #{site_import.site.domain}")
    |> render(import_api.email_template(), %{
      site_import: site_import,
      label: label,
      user: user,
      success: false
    })
  end

  def export_success(user, site, expires_at) do
    expires_in =
      if expires_at do
        Timex.Format.DateTime.Formatters.Relative.format!(
          expires_at,
          "{relative}"
        )
      end

    download_url =
      PlausibleWeb.Router.Helpers.site_url(
        PlausibleWeb.Endpoint,
        :download_export,
        site.domain
      )

    priority_email()
    |> to(user)
    |> tag("export-success")
    |> subject("[#{Plausible.product_name()}] Your export is now ready for download")
    |> render(:export_success,
      user: user,
      site: site,
      download_url: download_url,
      expires_in: expires_in
    )
  end

  def export_failure(user, site) do
    priority_email()
    |> to(user)
    |> subject("[#{Plausible.product_name()}] Your export has failed")
    |> render(:export_failure, user: user, site: site)
  end

  def error_report(reported_by, trace_id, feedback) do
    Map.new()
    |> Map.put(:layout, nil)
    |> base_email()
    |> to("bugs@plausible.io")
    |> put_param("ReplyTo", reported_by)
    |> tag("sentry")
    |> subject("Feedback to Sentry Trace #{trace_id}")
    |> render(:error_report_email, %{
      reported_by: reported_by,
      feedback: feedback,
      trace_id: trace_id
    })
  end

  def approaching_accept_traffic_until(notification) do
    base_email()
    |> to(notification.email)
    |> tag("drop-traffic-warning-first")
    |> subject("We'll stop counting your stats")
    |> render(:approaching_accept_traffic_until,
      time: "next week",
      user: %{email: notification.email, name: notification.name}
    )
  end

  def approaching_accept_traffic_until_tomorrow(notification) do
    base_email()
    |> to(notification.email)
    |> tag("drop-traffic-warning-final")
    |> subject("A reminder that we'll stop counting your stats tomorrow")
    |> render(:approaching_accept_traffic_until,
      time: "tomorrow",
      user: %{email: notification.email, name: notification.name}
    )
  end

  @doc """
    Unlike the default 'base' emails, priority emails cannot be unsubscribed from. This is achieved
    by sending them through a dedicated 'priority' message stream in Postmark.
  """
  def priority_email(), do: priority_email(%{layout: :priority_email})

  def priority_email(%{layout: layout}) do
    base_email(%{layout: layout})
    |> put_param("MessageStream", "priority")
  end

  def base_email(), do: base_email(%{layout: :base_email})

  def base_email(%{layout: layout}) do
    mailer_from = Application.get_env(:plausible, :mailer_email)

    new_email()
    |> put_param("TrackOpens", false)
    |> from(mailer_from)
    |> maybe_put_layout(layout)
  end

  defp maybe_put_layout(email, nil), do: email

  defp maybe_put_layout(email, layout) when is_atom(layout) do
    put_layout(email, {PlausibleWeb.LayoutView, layout})
  end
end
