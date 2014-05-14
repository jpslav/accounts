# References:
#   https://gist.github.com/stefanobernardi/3769177

class SessionsController < ApplicationController

  acts_as_interceptor

  add_interceptor(:authentication, :intercepted_url_key => :return_to)

  skip_before_filter :authenticate_user!, only: [:new, :callback,
                                                 :failure, :destroy]

  skip_intercept_with IdentitiesController, :password_reset
  skip_intercept_with UsersController, :registration

  fine_print_skip_signatures :general_terms_of_use,
                             :privacy_policy,
                             only: [:new, :callback, :failure,
                                    :destroy, :ask_new_or_returning]

  def new
    referer = request.referer
    session[:from_cnx] = (referer =~ /cnx\.org/) unless referer.blank?
    @application = Doorkeeper::Application.where(uid: params[:client_id]).first
  end

  def callback
    handle_with(SessionsCallback, user_state: self,
      complete: lambda {
        case @handler_result.outputs[:status]
        when SessionsCallback::RETURNING_USER
          redirect_from :authentication
        when SessionsCallback::NEW_USER       then render :ask_new_or_returning
        when SessionsCallback::MULTIPLE_USERS then render :ask_which_account
        else                                  raise IllegalState
        end
      })
  end

  def destroy
    sign_out!
    redirect_from :authentication, notice: "Signed out!"
  end

  def ask_new_or_returning
  end

  def i_am_returning
  end

  # Omniauth failure endpoint
  def failure
    flash.now[:alert] = params[:message] == 'invalid_credentials' ?
                          'Incorrect username or password' : params[:message]
    render 'new'
  end

end
