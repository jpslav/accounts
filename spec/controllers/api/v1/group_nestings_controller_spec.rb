require "spec_helper"

describe Api::V1::GroupNestingsController, :type => :api, :version => :v1 do

  let!(:group_1) { FactoryGirl.create :group, name: 'Group 1',
                                      members_count: 0, owners_count: 0 }
  let!(:group_2) { FactoryGirl.create :group, name: 'Group 2',
                                      members_count: 0, owners_count: 0 }
  let!(:group_3) { FactoryGirl.create :group, name: 'Group 3',
                                      members_count: 0, owners_count: 0, is_public: true }

  let!(:user_1)       { FactoryGirl.create :user, :terms_agreed }
  let!(:user_2)       { FactoryGirl.create :user, :terms_agreed }

  let!(:group_nesting_1) { FactoryGirl.create :group_nesting, container_group: group_1,
                                                              member_group: group_2 }

  let!(:untrusted_application) { FactoryGirl.create :doorkeeper_application }

  let!(:user_1_token) { FactoryGirl.create :doorkeeper_access_token,
                        application: untrusted_application,
                        resource_owner_id: user_1.id }
  let!(:user_2_token) { FactoryGirl.create :doorkeeper_access_token,
                        application: untrusted_application,
                        resource_owner_id: user_2.id }
  let!(:untrusted_application_token) { FactoryGirl.create :doorkeeper_access_token,
                                       application: untrusted_application,
                                       resource_owner_id: nil }

  context 'create' do
    it 'must not create a group_nesting without a token' do
      expect{api_post :create, nil, parameters: {group_id: group_3.id,
                                                 member_group_id: group_1.id}}.to(
        raise_error(SecurityTransgression))

      expect(response.body).to be_empty
    end

    it 'must not create a group_nesting for an app without a user token' do
      expect{api_post :create, untrusted_application_token,
                      parameters: {group_id: group_3.id,
                                   member_group_id: group_1.id}}.to(
        raise_error(SecurityTransgression))

      expect(response.body).to be_empty
    end

    it 'must not create a group_nesting for an unauthorized user' do
      expect{api_post :create, user_1_token, parameters: {group_id: group_3.id,
                                                          member_group_id: group_1.id}}.to(
        raise_error(SecurityTransgression))

      expect(response.body).to be_empty

      group_3.add_owner(user_1)
      controller.current_human_user.reload

      expect{api_post :create, user_1_token, parameters: {group_id: group_3.id,
                                                          member_group_id: group_1.id}}.to(
        raise_error(SecurityTransgression))

      expect(response.body).to be_empty

      GroupOwner.last.destroy
      group_1.add_owner(user_1)
      controller.current_human_user.reload

      expect{api_post :create, user_1_token, parameters: {group_id: group_3.id,
                                                          member_group_id: group_1.id}}.to(
        raise_error(SecurityTransgression))

      expect(response.body).to be_empty
    end

    it 'must create group_nestings for authorized users' do
      group_3.add_owner(user_1)
      group_1.add_owner(user_1)
      api_post :create, user_1_token, parameters: {group_id: group_3.id,
                                                   member_group_id: group_1.id}

      expect(response.code).to eq('201')
      expected_response = {'container_group_id' => group_3.id,
                           'member_group_id' => group_1.id}
      expect(JSON.parse(response.body)).to eq(expected_response)
    end
  end

  context 'destroy' do
    it 'must not destroy a group_nesting without a token' do
      expect{api_delete :destroy, nil,
                        parameters: {group_id: group_1.id,
                                     member_group_id: group_2.id}}.to(
        raise_error(SecurityTransgression))

      expect(response.body).to be_empty
      expect(GroupNesting.where(id: group_nesting_1.id).first).not_to be_nil
    end

    it 'must not destroy a group_nesting for an app without a user token' do
      expect{api_delete :destroy, untrusted_application_token,
                        parameters: {group_id: group_1.id,
                                     member_group_id: group_2.id}}.to(
        raise_error(SecurityTransgression))

      expect(response.body).to be_empty
      expect(GroupNesting.where(id: group_nesting_1.id).first).not_to be_nil
    end

    it 'must not destroy a group_nesting for an unauthorized user' do
      expect{api_delete :destroy, user_1_token,
                        parameters: {group_id: group_1.id,
                                     member_group_id: group_2.id}}.to(
        raise_error(SecurityTransgression))

      expect(response.body).to be_empty
      expect(GroupNesting.where(id: group_nesting_1.id).first).not_to be_nil

      group_2.add_member(user_1)

      expect{api_delete :destroy, user_1_token,
                        parameters: {group_id: group_1.id,
                                     member_group_id: group_2.id}}.to(
        raise_error(SecurityTransgression))

      expect(response.body).to be_empty
      expect(GroupNesting.where(id: group_nesting_1.id).first).not_to be_nil
    end

    it 'must destroy group_nestings for authorized users' do
      group_nesting_2 = FactoryGirl.create(:group_nesting, container_group: group_3,
                                                           member_group: group_1)
      group_1.add_owner(user_1)
      api_delete :destroy, user_1_token,
                 parameters: {group_id: group_3.id,
                              member_group_id: group_1.id}

      expect(response.code).to eq('204')
      expect(response.body).to be_blank
      expect(GroupNesting.where(id: group_nesting_2.id).first).to be_nil

      api_delete :destroy, user_1_token,
                 parameters: {group_id: group_1.id,
                              member_group_id: group_2.id}

      expect(response.code).to eq('204')
      expect(response.body).to be_blank
      expect(GroupNesting.where(id: group_nesting_1.id).first).to be_nil
    end
  end

end
