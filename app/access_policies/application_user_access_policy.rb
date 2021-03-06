class ApplicationUserAccessPolicy
  # Contains all the rules for which requestors can do what with which ApplicationUser objects.

  def self.action_allowed?(action, requestor, application_user)
    # Human users are not allowed
    return false if requestor.is_human?

    # Apps can only call search, updates and updated
    return [:search, :updates, :updated].include?(action)
  end

end
