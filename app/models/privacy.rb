class Privacy < ActiveRecord::Base
  acts_as_enum

  validates_presence_of :name
end