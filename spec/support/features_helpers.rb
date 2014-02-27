def create_user username, password='password'
  return if User.find_by_username(username).present?
  user = FactoryGirl.create :user_with_person, username: username
  identity = FactoryGirl.create :identity, user: user, password: password
  FactoryGirl.create :authentication, provider: 'identity', uid: identity.id.to_s, user: user
  return user
end

def create_user_with_plone_password
  user = create_user 'plone_user'
  # update user's password digest to be "password" using the plone hashing algorithm
  user.identity.update_attribute(:password_digest, '{SSHA}RmBlDXdkdJaQkDsr790+eKaY9xHQdPVNwD/B')
end

def create_admin_user
  user = create_user 'admin'
  user.is_administrator = true
  user.save
end

def login_as username, password='password'
  fill_in 'Username', with: username
  fill_in 'Password', with: password
  click_button 'Sign in'
end

def create_new_application
  click_link 'New Application'
  fill_in 'Name', with: 'example'
  fill_in 'Redirect uri', with: 'http://localhost/'
  check 'Trusted?'
  click_button 'Submit'
end

def create_email_address_for user, email_address, confirmation_code
  FactoryGirl.create(:email_address, user: user, value: email_address,
                     confirmation_code: confirmation_code)
end

def generate_reset_code_for(username)
  user = User.find_by_username(username)
  identity = user.identity
  identity.generate_reset_code
  identity.reset_code
end

def generate_expired_reset_code_for(username)
  one_year_ago = 1.year.ago
  DateTime.stub(:now).and_return(one_year_ago)
  reset_code = generate_reset_code_for username
  DateTime.unstub(:now)
  reset_code
end
