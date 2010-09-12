class SubjectsController < BaseController

  layout 'new_application'
  before_filter :login_required
 

  def index
#    session[:subject_step] = session[:subject_params]= session[:subject_aulas]= session[:subject_id]= session[:subject_exames]  = nil
#    
#    if params[:school_id].nil?
#    @subjects = Subject.find(:all, :conditions => "is_public like true") 
#   else
#     @subjects = current_user.schools.find(params[:school_id]).subjects#.paginate(paginating_params)
#   end
#   
#   
#    respond_to do |format|
#     format.html # index.html.erb
#
#     format.js  do     
#       render :update do |page|
#         page.replace_html  'content_list', :partial => 'subjects/school/subject_list/'
#         page << "$('#spinner').hide()"
#       end
#     end  
#     
#   end



    cond = Caboose::EZ::Condition.new
    cond.append ["simple_category_id = ?", params[:category]] if params[:category]
    
    paginating_params = {
      :conditions => cond.to_sql,
      :page => params[:page], 
      :order => (params[:sort]) ? params[:sort] + ' DESC' : 'created_at DESC', 
      :per_page => AppConfig.items_per_page 
    }
    
    if params[:user_id] # cursos do usuario
      @user = User.find_by_login(params[:user_id]) 
      @user = User.find(params[:user_id]) unless @user
      @subjects = @user.subjects.paginate(paginating_params)
      render((@user == current_user) ? "user_subjects_private" :  "user_subjects_public") #TODO
      return
      
    elsif params[:school_id] # cursos da escola
      @school = School.find(params[:school_id])
      if params[:search] # search cursos da escola
        @subjects = @school.subjects.name_like_all(params[:search].to_s.split).ascend_by_name.paginate(paginating_params)
      else
        @subjects = @school.subjects.paginate(paginating_params) 
      end
    else # index (Course)
      if params[:search] # search
        @subjects = Subject.name_like_all(params[:search].to_s.split).ascend_by_name.paginate(paginating_params)
      else
        @subjects = Subject.paginate(paginating_params)
      end
    end
    
    # @popular_tags = Course.tag_counts
    
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @subjects }
      
      format.js  do
        if params[:school_content]
          render :update do |page|
             page.replace_html  'content_list', :partial => 'subject_list'
             page << "$('#spinner').hide()"
          end
#        elsif params[:tab]
#          render :update do |page|
#            page.replace_html  'tabs-2-content', :partial => 'courses_school'
#          end
        else
          render :index
        end
        
      end
    end
 end
  

  def show
    
      @subject = Subject.find(:first, :conditions => "is_public like true AND id =#{params[:id].to_i}")
     respond_to do |format|    
         if current_user.enrollments.detect{|e| e.subject_id.eql?(params[:id].to_i)}.nil?
         format.html
         else
          format.html{  render :action => "classes" }
         end
     end
     
  end

  def new
   # session[:subject_params] ||= {}
    cancel
    @subject = Subject.new
  end

  def create
    session[:subject_params].deep_merge!(params[:subject]) if params[:subject]
    session[:subject_aulas]= params[:aulas] unless params[:aulas].nil?
    session[:subject_exames] = params[:exams] unless params[:exams].nil?
    
    @subject = current_user.subjects.new(session[:subject_params])
    @subject.current_step = params[:step]#session[:subject_step] assim evita que ao dar refresh vá para o proximo passo
    
    if  @subject.valid?
      if params[:back_button]
        @subject.previous_step
      elsif @subject.last_step?
        
        if @subject.all_valid?
          @subject.save
          @subject.create_course_subject_type_course(session[:subject_aulas], @subject.id, current_user) unless session[:subject_aulas].nil?
          @subject.create_course_subject_type_exam(session[:subject_exames], @subject.id, current_user) unless session[:subject_exames].nil?
        end
      else
        @subject.next_step
      end
      session[:subject_step]= @subject.current_step
    end

    if @subject.new_record?
      render "new"
    else
      session[:subject_step] = session[:subject_params]= session[:subject_aulas]=session[:subject_exames] = nil
       redirect_to :action =>"admin_subjects"
    end
  end
  
  def cancel
    session[:subject_step] = session[:subject_params]= session[:subject_aulas]= session[:subject_id]= session[:subject_exames]  = nil
  end


  def edit
    session[:subject_params] ||= {}
    @subject = current_user.subjects.find(params[:id])
  end
 
  def update 
    updated = false 
    session[:subject_params].deep_merge!(params[:subject]) if params[:subject]
    session[:subject_aulas]= params[:aulas] unless params[:aulas].nil?
    session[:subject_id]= params[:id] unless params[:id].nil?
    session[:subject_exames] = params[:exams] unless params[:exams].nil?

    @subject = current_user.subjects.new(session[:subject_params])
    @subject.current_step = session[:subject_step]

    if  @subject.valid?
      if params[:back_button]
        @subject.previous_step
      elsif @subject.last_step?

        if @subject.all_valid?
          @subject = current_user.subjects.find(session[:subject_id])
          @subject.update_attributes(session[:subject_params])
          @subject.course_subjects.destroy_all
          @subject.create_course_subject_type_course(session[:subject_aulas], @subject.id,current_user) unless session[:subject_aulas].nil?
          @subject.create_course_subject_type_exam(session[:subject_exames], @subject.id, current_user) unless session[:subject_exames].nil?
        end
          updated = true
      else
        @subject.next_step
      end
      session[:subject_step]= @subject.current_step
    end

    unless updated
      render "edit"
    else
      flash[:notice] = "Atualizado com sucesso!"
      session[:subject_step] = session[:subject_params]= session[:subject_aulas]= session[:subject_exames]= session[:subject_id] = nil
      redirect_to :action =>"admin_subjects"
    end

  end
 
  def destroy
    subject = current_user.subjects.find(params[:id].to_i)
    subject.destroy
    redirect_to :action =>"admin_subjects"
  end

  def classes
    Enrollment.create_enrollment(params[:id], current_user)
    @subject = Subject.find(:first, :conditions => "is_public like true AND id =#{params[:id].to_i}")
  end
  
  def admin_subjects
    @subjects = current_user.subjects
  end
  
  def admin_show
    @subject = current_user.subjects.find(params[:id])
    
  end
  
 
    

end
