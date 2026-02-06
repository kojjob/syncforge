defmodule Syncforge.Accounts.UserEmail do
  @moduledoc """
  Email templates for user account operations (password reset, email confirmation).
  """

  import Swoosh.Email

  @from {"SyncForge", "noreply@syncforge.io"}

  @doc """
  Builds a password reset email with the given reset URL.
  """
  def password_reset_email(user, reset_url) do
    new()
    |> to({user.name, user.email})
    |> from(@from)
    |> subject("Reset your password")
    |> text_body("""
    Hi #{user.name},

    You requested a password reset for your SyncForge account.

    Click the link below to reset your password (expires in 1 hour):

    #{reset_url}

    If you did not request this, please ignore this email.
    """)
    |> html_body("""
    <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto;">
      <h2>Reset your password</h2>
      <p>Hi #{user.name},</p>
      <p>You requested a password reset for your SyncForge account.</p>
      <p>
        <a href="#{reset_url}"
           style="display: inline-block; padding: 12px 24px; background-color: #4F46E5;
                  color: white; text-decoration: none; border-radius: 6px; font-weight: bold;">
          Reset Password
        </a>
      </p>
      <p style="color: #6B7280; font-size: 14px;">
        This link expires in 1 hour. If you did not request this, please ignore this email.
      </p>
    </div>
    """)
  end

  @doc """
  Builds an email confirmation email with the given confirm URL.
  """
  def confirmation_email(user, confirm_url) do
    new()
    |> to({user.name, user.email})
    |> from(@from)
    |> subject("Confirm your email address")
    |> text_body("""
    Hi #{user.name},

    Welcome to SyncForge! Please confirm your email address by clicking the link below:

    #{confirm_url}

    This link expires in 7 days.
    """)
    |> html_body("""
    <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto;">
      <h2>Confirm your email</h2>
      <p>Hi #{user.name},</p>
      <p>Welcome to SyncForge! Please confirm your email address.</p>
      <p>
        <a href="#{confirm_url}"
           style="display: inline-block; padding: 12px 24px; background-color: #4F46E5;
                  color: white; text-decoration: none; border-radius: 6px; font-weight: bold;">
          Confirm Email
        </a>
      </p>
      <p style="color: #6B7280; font-size: 14px;">
        This link expires in 7 days.
      </p>
    </div>
    """)
  end
end
