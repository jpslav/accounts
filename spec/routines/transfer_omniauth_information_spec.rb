require 'spec_helper'

describe TransferOmniauthInformation do
  context 'when auth provider is facebook' do
    it 'stores user information' do
      auth_hash = OmniAuth::AuthHash.new provider: 'facebook', uid: '1234567890'
      auth_hash.extra = {
        raw_info: {
          email: 'user@example.com',
          first_name: 'User',
          last_name: 'One',
          gender: 'female',
          id: '1234567890',
          languages: [{id: '106059522759137', name: 'English'}],
          link: 'https://www.facebook/user.one',
          locale: 'en_US',
          location: {id: '116045151742300', name: 'Munich, Germany'},
          name: 'Karen Chan',
          timezone: 1,
          updated_time: '2013-07-28T18:22:46+0000',
          username: 'user1',
          verifeid: 'true',
        },
      }
      auth_hash.info = {
        email: 'user@example.com',
        first_name: 'User',
        image: 'http://graph.facebook.com/1234567890/picture?type=square',
        last_name: 'One',
        location: 'Munich, Germany',
        name: 'User One',
        nickname: 'user1',
        urls: {Facebook: 'https://www.facebook.com/cw0418'},
        verified: true
      }

      user = FactoryGirl.create :user
      TransferOmniauthInformation.call(auth_hash, user)
      expect(user.contact_infos.length).to eq(1)
      expect(user.contact_infos[0].type).to eq('EmailAddress')
      expect(user.contact_infos[0].value).to eq('user@example.com')
      expect(user.contact_infos[0].verified).to be_true
    end
  end

  context 'when auth provider is identity' do
    it 'raises error because we should not get here' do
      user = FactoryGirl.create :user
      auth_hash = OmniAuth::AuthHash.new provider: 'identity', uid: '12345'
      expect { TransferOmniauthInformation.call auth_hash, user }.to raise_error(Unexpected)
    end
  end

  context 'when auth provider is twitter' do
    it 'stores user information' do
      user = FactoryGirl.create :user
      auth_hash = OmniAuth::AuthHash.new provider: 'twitter', uid: '12345678'
      auth_hash.extra = {
        oauth_token: '12345678-abcdefg',
        user_id: '12345678',
        screen_name: 'user1',
        raw_info: {
          contributors_enabled: false,
          created_at: 'Wed Nov 26 11:04:13 +0000 2013',
          default_profile: false,
          default_profile_image: false,
          description: 'User one profile description text',
          entities: { description: { urls: [] } },
          url: { urls: [{ display_url: 'example.com', expanded_url: 'http://example.com', url: 'http://t.co/XYZ' }] },
          id: 12345678,
          id_str: '12345678',
          lang: 'en',
          location: 'Munich, Germany',
          name: 'User One',
          notifications: false,
          profile_image_url: 'http://pbs.twimg.com/profile_images/12345678/me.jpg',
          profile_image_url_https: 'https://pbs.twimg.com/profile_images/12345678/me.jpg',
          screen_name: 'user1',
        },
      }
      auth_hash.info = {
        description: 'User one profile description text',
        image: 'http://pbs.twimg.com/profile_images/12345678/me.jpg',
        location: 'Munich, Germany',
        name: 'User One',
        nickname: 'user1',
        urls: {
          Twitter: 'https://twitter.com/karenc4',
          Website: 'http://example.com',
        },
      }
      TransferOmniauthInformation.call(auth_hash, user)
      expect(user.contact_infos).to be_empty
    end
  end

  context 'when auth provider is google' do
    it 'stores user information' do
      user = FactoryGirl.create :user
      auth_hash = OmniAuth::AuthHash.new provider: 'google_oauth2', uid: '12345678901234567890'
      auth_hash.extra = {
        id_token: 'SoMeLoNgRaNdOmStRiNg',
        raw_info: {
          email: 'user@example.com',
          family_name: 'One',
          gender: 'female',
          given_name: 'User',
          hd: 'example.com',
          id: '1234567890',
          link: 'https://plus.google.com/1234567890',
          locale: 'en',
          name: 'User One',
          picture: 'https://lh5.googleusercontent.com/xxxxxx/yyyyy/photo.jpg',
          verified_email: true,
        },
      }
      auth_hash.info = {
        email: 'user@example.com',
        first_name: 'User',
        image: 'https://lh5.googleusercontent.com/xxxxxx/yyyyy/photo.jpg',
        last_name: 'One',
        name: 'User One',
        urls: { Google: 'https://plus.google.com/1234567890' },
      }
      TransferOmniauthInformation.call(auth_hash, user)
      expect(user.contact_infos.length).to eq(1)
      expect(user.contact_infos[0].type).to eq('EmailAddress')
      expect(user.contact_infos[0].value).to eq('user@example.com')
      expect(user.contact_infos[0].verified).to be_true
    end
  end

  context 'when auth provider is unknown' do
    it 'raises error' do
      user = FactoryGirl.create :user
      auth_hash = OmniAuth::AuthHash.new provider: 'me', uid: '12345'
      expect { TransferOmniauthInformation.call auth_hash, user }.to raise_error(IllegalArgument)
    end
  end
end
