
# Routine for searching for users
# 
# Caller provides a query and some options.  The query follows the rules of
# https://github.com/bruce/keyword_search, e.g.:
#
#   "username:jps,richb" --> returns the "jps" and "richb" users
#   "name:John" --> returns Users with first, last, or full name starting with "John"
#
# Query terms can be combined, e.g. "username:jp first_name:john"
#
# There are currently two options to control query pagination:
#
#   :per_page -- the number of results to return (max)
#   :page     -- the page to return

class SearchUsers

  lev_routine transaction: :no_transaction

protected

  NAME_DISCARDED_CHAR_REGEX = /[^A-Za-z ']/

  # TODO increase the security of this search algorithm:
  # 
  #   For certain users we might want to restrict the fields that can be searched 
  #   as well as the fields that are returned.  For example, we probably don't want 
  #   to return email address information to an OpenStax SPA in a client's browser, 
  #   but we'd be ok returning email addresses directly to an OpenStax server.
  #
  #   I favor an approach where no permissions are granted by default -- where the
  #   requesting code has to explicitly say that the search routine can search by
  #   such and such fields and return such and such other fields.  That way it protects
  #   us from accidentally using more fields than we should.
  #
  #   For restriction what fields we return we can use a "select" clause on our query.
  #   This works for fields in User, but what about restricting access to associated
  #   ContactInfos?  Ideally we'd be able to prevent other code from being able to send
  #   this info back to the requestor.  Maybe this logic has to go outside of this class
  #   (like in the API representer or view code).
  #
  #   We should prohibit Users from searching by username or name if they don't provide
  #   enough characters (so as to discourage them from querying all Users or from 
  #   querying all Users whose username starts with 'a', then 'b', then 'c' and so on).
  #   What to do if a first name is "V" or "JP" -- hard to make this restriction here.

  def exec(query, options={}, type=:any)
    users = User.scoped
    
    KeywordSearch.search(query) do |with|

      with.keyword :username do |usernames|
        usernames = usernames.collect do |username| 
          username.gsub(User::USERNAME_DISCARDED_CHAR_REGEX,'').downcase + '%'
        end

        users = users.where{username.like_any usernames}
      end

      with.keyword :first_name do |first_names|
        users = users.where{lower(first_name).like_any my{prep_names(first_names)}}
      end

      with.keyword :last_name do |last_names|
        users = users.where{lower(last_name).like_any my{prep_names(last_names)}}
      end

      with.keyword :full_name do |full_names|
        users = users.where{lower(full_name).like_any my{prep_names(full_names)}}
      end

      with.keyword :name do |names|
        users = users.where{lower(full_name).like_any my{prep_names(full_names)} |
                            lower(last_name).like_any my{prep_names(last_names)} |
                            lower(first_name).like_any my{prep_names(first_names)}}
      end

      with.keyword :id do |ids|
        users = users.where{id.in ids}
      end

      with.keyword :email do |emails|
        users = users.joins{contact_infos}
                     .where{{contact_infos: sift(:email_addresses)}}
                     .where{{contact_infos: sift(:verified)}}
                     .where{contact_infos.value.in emails}
      end

    end

    # If the query didn't result in any restrictions, either because it was blank
    # or didn't have a keyword from above with appropriate values, then return no
    # results.

    users = User.where('0=1') if User.scoped == users

    # Pagination

    if options[:page] && options[:per_page]
      users = users.limit(options[:per_page]).offset(options[:per_page]*options[:page])
    end

    outputs[:users] = users
  end

  # Through out funky characters, downcase, and put a wildcard at the end.
  def prep_names(names)
    names.collect{|name| name.gsub(NAME_DISCARDED_CHAR_REGEX, '').downcase + '%'}
  end

  # Musings on convenience methods for pulling the fields we can search or return
  # out of the options hash passed to `exec`.
  #
  # class Options
  #   def initialize(hash)
  #   end
  #
  #   def can_search?(field)
  #   end
  #
  #   def can_return?(field)
  #   end
  # end

end