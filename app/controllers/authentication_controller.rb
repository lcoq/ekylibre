class AuthenticationController < ApplicationController
  
  def index
    redirect_to :action=>:login
  end
  
  def retrieve
    retrieve_xil(params[:id],:key=>params[:id])
  end
  
  def render_f
    render_xil(params[:id].to_i, :key=>1, :output=>:pdf, :crypt=>:none)
    #render_xil("<?xml?><template title='Example' orientation='portrait' format='210x297' unit='mm' query-standard='sql' size='10' ><title>ToTo</title></template>", :key=>1, :output=>:pdf)    
    #  render_xil("lib/template.xsd", :key=>1, :output=>:pdf)    
    #render_xil(Template.find(2), :key=>1, :output=>:pdf)    
  end
  
  def login
    @login = 'lf'
    if request.post?
      user = User.authenticate(params[:user][:name], params[:user][:password])
      if user
        init_session(user)
        unless session[:user_id].blank?
          if session[:last_controller].to_s == self.controller_name or session[:last_controller].blank?
            redirect_to :controller=>:guide, :action=>:index 
          else
            redirect_to :controller=>session[:last_controller], :action=>session[:last_action]
          end
        end
      else
        flash[:error] = lc :no_authenticated
      end
      session[:user_name] = params[:user][:name]
    end
  end
  
  def register
    if request.post?
      if session[:company_id].nil?
        @company = Company.new(params[:company])
      else
        @company = Company.find(session[:company_id])
        @company.attributes = params[:company]
      end
      if @company.save
        session[:company_id] = @company.id
        params[:user][:company_id] = @company.id
        @user = User.new(params[:user])
        @user.role_id = @company.admin_role.id
        if @user.save
          init_session(@user)
          redirect_to :controller=>:guide, :action=>:welcome
        end
      end
    else
      session[:company_id] = nil
      @company = Company.new
      @user = User.new
    end
  end
  
   def logout
    session[:user_id] = nil    
    session[:last_controller] = nil
    session[:last_action] = nil
    reset_session
    redirect_to :action=>:login
  end
  
  protected
  
  def init_session(user)
    session[:user_id] = user.id
    session[:last_query] = Time.now.to_i
    session[:expiration] = 3600
    session[:menu_guide] = user.company.menu("guide") 
    session[:menu_user]  = user.company.menu("user")
    
  end
  
end
