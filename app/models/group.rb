class Group < ActiveRecord::Base

  serialize :cached_supertree_group_ids
  serialize :cached_subtree_group_ids

  has_many :group_owners, dependent: :destroy, inverse_of: :group
  has_many :owners, through: :group_owners, source: :user

  has_many :group_members, dependent: :destroy, inverse_of: :group
  has_many :members, through: :group_members, source: :user

  has_one :container_group_nesting, dependent: :destroy,
          class_name: 'GroupNesting',
          foreign_key: :member_group_id, inverse_of: :member_group
  has_one :container_group, through: :container_group_nesting

  has_many :member_group_nestings, dependent: :destroy,
           class_name: 'GroupNesting',
           foreign_key: :container_group_id, inverse_of: :container_group
  has_many :member_groups, through: :member_group_nestings

  has_many :oauth_applications, as: :owner, class_name: 'Doorkeeper::Application'

  has_many :application_groups, dependent: :destroy, inverse_of: :group

  validates_uniqueness_of :name, allow_nil: true

  before_save :add_unread_update

  scope :visible_for, lambda { |user|
    next where(is_public: true) unless user.is_a? User

    includes(:group_members).includes(:group_owners)
    .where{((is_public.eq true) |\
             (group_members.user_id.eq my{user.id}) |\
             (group_owners.user_id.eq my{user.id}))}
  }

  def has_owner?(user)
    return false unless user.is_a? User
    !group_owners.where(user_id: user.id).first.nil?
  end

  def has_direct_member?(user)
    return false unless user.is_a? User
    !group_members.where(user_id: user.id).first.nil?
  end

  def has_member?(user)
    return false unless user.is_a? User
    !user.group_members.where(group_id: subtree_group_ids).first.nil?
  end

  def add_owner(user)
    return false unless user.is_a? User
    go = GroupOwner.new
    go.group = self
    go.user = user
    return false unless go.valid?
    go.save if persisted?
    group_owners << go
  end

  def add_member(user)
    return false unless user.is_a? User
    gm = GroupMember.new
    gm.group = self
    gm.user = user
    return false unless gm.valid?
    gm.save if persisted?
    group_members << gm
  end

  def supertree_group_ids
    return cached_supertree_group_ids unless cached_supertree_group_ids.nil?
    return [] unless persisted?
    reload

    gids = [id] + (Group.includes(:member_group_nestings)
                        .where(member_group_nestings: {member_group_id: id})
                        .first.try(:supertree_group_ids) || [])
    update_column(:cached_supertree_group_ids, gids.to_yaml)
    self.cached_supertree_group_ids = gids
  end

  def subtree_group_ids
    return cached_subtree_group_ids unless cached_subtree_group_ids.nil?
    return [] unless persisted?
    reload

    gids = [id] + Group.includes(:container_group_nesting)
                       .where(container_group_nesting: {container_group_id: id})
                       .collect{|g| g.subtree_group_ids}.flatten
    update_column(:cached_subtree_group_ids, gids.to_yaml)
    self.cached_subtree_group_ids = gids
  end

  def subtree_member_ids
    GroupMember.where(group_id: subtree_group_ids).uniq.pluck(:user_id)
  end

  def add_unread_update
    # Returns false if the update fails (aborting the save transaction)
    AddUnreadUpdateForGroup.call(self).errors.none?
  end

end
