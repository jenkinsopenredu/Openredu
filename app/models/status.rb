class Status < ActiveRecord::Base
  belongs_to :statusable, :polymorphic => true
  belongs_to :user
  has_many :answers, :as => :in_response_to,
    :dependent => :destroy,
    :order => "created_at ASC",
    :include => [:user]
  has_many :users, :through => :status_user_associations
  has_many :status_user_associations, :dependent => :destroy

  scope :from_hierarchy, lambda { |c|
    where(build_conditions(c)).includes(:user) \
      .order("updated_at DESC")
  }

  # Não utilizar o recent em consultas sem include e posteriomente,
  # na view, fazer as consultas
  scope :recent_from_hierarchy, lambda { |c|
    where(build_conditions(c)).where('created_at > ?', 1.week.ago)
  }

  # Constrói as condições de busca de status dentro da hierarquia. Aceita
  # Course, Space e Lecture como raíz
  def self.build_conditions(entity)
    statusables = statuables_on_hierarchy(entity)
    conditions = []

    statusables.each do |key, val|
      next if val.empty?

      ids = val.collect { |s| s.id }.join(',')
      conditions << "(statusable_type LIKE '#{key.to_s.classify}' AND " + \
        "statusable_id IN (#{ids}))"
    end

    return conditions.join(" OR ")
  end

  # Associa self à lista de usuários
  def associate_with(users)
    users.includes(:status_user_associations).each do |u|
      u.status_user_associations.create(:status => self)
    end
  end

  protected

  def self.statuables_on_hierarchy(root)
    groups = { :courses => [], :spaces => [], :lectures => [] }

    case root.class.to_s
    when 'Course'
      groups[:courses] = [root]
      groups[:spaces] = root.spaces.select("spaces.id")
      groups[:lectures] = lectures_or_nothing(groups[:spaces])
    when 'Space'
      groups[:spaces] = [root]
      groups[:lectures] = lectures_or_nothing(groups[:spaces])
    when 'Lecture'
      groups[:lectures] = [root]
    end

    groups
  end

  def self.lectures_or_nothing(spaces)
    spaces.collect do |space|
      space.subjects.select("subjects.id").collect do |subject|
        subject.lectures.select("lectures.id")
      end
    end.flatten
  end
end
