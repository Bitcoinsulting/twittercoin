class SessionsController < ApplicationController

  def create
    # raise request.env["omniauth.auth"].to_yaml
    auth = request.env["omniauth.auth"]

    user = User.find_profile(auth["info"]["nickname"]) || User.create_profile(auth["info"]["nickname"])
    user.uid = auth["uid"]
    user.authenticated = true
    binding.pry
    user.save

    session[:slug] = user.slug

    redirect_to "/#/account/", flash: {
      info: "Welcome!"
    }
  end

  def destroy
    session[:slug] = nil
    redirect_to "/", flash: {
      info: "See you next time!"
    }
  end

end
