##
# Folder model. Each instance of this class represents a single folder to which a user can add feeds.
#
# Each folder belongs to a single user, and each user can have many folders (one-to-many relationship).
#
# Each folder can be associated with many feeds, and each feed can be associated with many folders as long as they
# belong to different users (many-to-many relationship, through the feed_folders table). However a feed can be
# associated with at most one folder belonging to a single user.
#
# A relationship is also established between Folder and Entry models, through the Feed model. This enables us to retrieve
# all entries for all feeds inside a folder.
#
# The title field is mandatory. As it is introduced by the user, it is sanitized before saving in the database.
#
# A given user cannot have two folders with the same title. Folders with the same title are allowed as long as they
# belong to different users.

class Folder < ActiveRecord::Base
  include ActionView::Helpers::SanitizeHelper

  attr_accessible :title

  belongs_to :user
  validates :user_id, presence: true
  has_and_belongs_to_many :feeds, uniq: true, before_add: :single_user_folder, after_remove: :remove_empty_folders
  has_many :entries, through: :feeds

  validates :title, presence: true, uniqueness: {case_sensitive: false, scope: :user_id}
  validates :unread_entries, presence: true, numericality: {only_integer: true, greater_than_or_equal_to: 0}

  before_validation :before_folder_validation

  private

  ##
  # Before validation of the folder instance:
  # - give default value to its attributes
  # - sanitize those attributes that need it

  def before_folder_validation
    default_values
    sanitize_attributes
  end

  ##
  # By default the number of unread entries is zero, if not set.

  def default_values
    self.unread_entries = 0 if self.unread_entries.blank?
  end

  ##
  # Sanitize the title of the folder.
  #
  # Despite this sanitization happening before saving in the database, sanitize helpers must still be used in the views.
  # Better paranoid than sorry!

  def sanitize_attributes
    self.title = sanitize self.title
  end

  ##
  # Before adding a feed to a folder, check if the feed is already in another folder owned
  # by the same user. In this case, remove it from the old folder before adding it to the new one.

  def single_user_folder(feed)
    old_folder = feed.folders.where(user_id: self.user_id).first
    if old_folder.present?
      old_folder.feeds.delete feed
    end
  end

  ##
  # After removing a feed from a folder, check if there are no more feeds in the folder.
  # In this case, delete the folder from the database.

  def remove_empty_folders(feed)
    if self.feeds.blank?
      self.destroy
    end
  end
end
