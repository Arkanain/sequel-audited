class AuditLog < Sequel::Model
  # handle versioning of audited records
  plugin :list, field: :version, scope: [:model_type, :model_pk]
  plugin :timestamps

  # def before_validation
  #   # grab the current user
  #   u = audit_user
  #   self.user_id    = u.id
  #   self.username   = u.username
  #   self.user_type  = u.class.name ||= :User
  # end

  # private

  # Obtains the `current_user` based upon the `:audited_current_user_method' value set in the
  # audited model, either via defaults or via :user_method config options
  # 
  # # NOTE! this allows overriding the default value on a per audited model
  # def audit_user
  #   m = Kernel.const_get(model_type)
  #   send(m.audited_current_user_method)
  # end
end

module Sequel
  module Plugins
    # Given a Post model with these fields: 
    #   [:id, :category_id, :title, :body, :author_id, :created_at, :updated_at]
    #
    #
    # All fields
    #   plugin :audited 
    #     #=> [:category_id, :title, :body, :author_id]  # NB! excluding @default_ignore_attrs
    #     #=> [:id, :created_at, :updated_at]
    #
    # Single field
    #   plugin :audited, only: :title
    #   plugin :audited, only: [:title]
    #     #=> [:title]
    #     #+> [:id, :category_id, :body, :author_id, :created_at, :updated_at] # ignored fields
    # 
    # Multiple fields
    #   plugin :audited, only: [:title, :body]
    #     #=> [:title, :body] # tracked fields
    #     #=> [:id, :category_id, :author_id, :created_at, :updated_at] # ignored fields
    # 
    # 
    # All fields except certain fields
    #   plugin :audited, except: :title
    #   plugin :audited, except: [:title]
    #     #=> [:id, :category_id, :author_id, :created_at, :updated_at] # tracked fields
    #     #=> [:title] # ignored fields
    # 
    # 
    # 
    module Audited
      # called when 
      def self.configure(model, opts = {})
        model.instance_eval do
          # add support for :dirty attributes tracking & JSON serializing of data
          plugin :dirty
          plugin :json_serializer

          # set the default ignored columns or revert to defaults
          set_default_ignored_columns(opts)
          # sets the name of the current User method or revert to default: :current_user 
          # specifically for the audited model on a per model basis
          set_user_method(opts)

          only    = opts.fetch(:only, [])
          except  = opts.fetch(:except, [])

          unless only.empty?
            # we should only track the provided column
            included_columns = [only].flatten
            # subtract the 'only' columns from all columns to get excluded_columns
            excluded_columns = columns - included_columns
          else # except:
            # all columns minus any excepted columns and default ignored columns
            included_columns = [
              [columns - [except].flatten].flatten - @audited_default_ignored_columns
            ].flatten.uniq

            # except_columns = except.empty? ? [] : [except].flatten
            excluded_columns = [columns - included_columns].flatten.uniq
            # excluded_columns = [columns - [except_columns, included_columns].flatten].flatten.uniq
          end

          @audited_included_columns = included_columns
          @audited_ignored_columns  = excluded_columns

          # each included model will have an associated versions
          one_to_many(
            :versions,
            class: audit_model_name,
            key: :model_pk,
            conditions: { model_type: model.name.to_s }
          )
        end
      end

      module ClassMethods
        attr_accessor :audited_default_ignored_columns, :audited_current_user_method
        # The holder of ignored columns
        attr_reader :audited_ignored_columns
        # The holder of columns that should be audited
        attr_reader :audited_included_columns

        Plugins.inherited_instance_variables(self,
                                             :@audited_default_ignored_columns => nil,
                                             :@audited_current_user_method     => nil,
                                             :@audited_included_columns        => nil,
                                             :@audited_ignored_columns         => nil
        )

        def non_audited_columns
          columns - audited_columns
        end

        def audited_columns
          @audited_columns ||= columns - @audited_ignored_columns
        end

        # returns true / false if any audits have been made
        # 
        #   Post.audited_versions?   #=> true / false
        # 
        def audited_versions?
          audit_model.where(model_type: name.to_s).count >= 1
        end

        # grab all audits for a particular model based upon filters
        #   
        #   Posts.audited_versions(:model_pk => 123)
        #     #=> filtered by primary_key value
        #    
        #   Posts.audited_versions(:user_id => 88)
        #     #=> filtered by user name
        #     
        #   Posts.audited_versions(:created_at < Date.today - 2)
        #     #=> filtered to last two (2) days only
        #     
        #   Posts.audited_versions(:created_at > Date.today - 7)
        #     #=> filtered to older than last seven (7) days
        #     
        def audited_versions(opts = {})
          audit_model.where(opts.merge(model_type: name.to_s)).order(:version).all
        end

        private

        def audit_model
          const_get(audit_model_name)
        end

        def audit_model_name
          ::Sequel::Audited.audited_model_name
        end

        def set_default_ignored_columns(opts)
          if opts[:default_ignored_columns]
            @audited_default_ignored_columns = opts[:default_ignored_columns]
          else
            @audited_default_ignored_columns = ::Sequel::Audited.audited_default_ignored_columns
          end
        end

        def set_user_method(opts)
          if opts[:user_method]
            @audited_current_user_method = opts[:user_method]
          else
            @audited_current_user_method = ::Sequel::Audited.audited_current_user_method
          end
        end

      end

      module InstanceMethods
        # Returns who put the post into its current state.
        #   
        #   post.blame  # => 'joeblogs'
        #   
        #   post.last_audited_by  # => 'joeblogs'
        # 
        # Note! returns 'not audited' if there's no audited version (new unsaved record)
        # 
        def blame
          v = versions.last unless versions.empty?
          v ? v.username : 'not audited'
        end
        alias_method :last_audited_by, :blame

        # Returns who put the post into its current state.
        #   
        #   post.last_audited_at  # => '2015-12-19 @ 08:24:45'
        #   
        #   post.last_audited_on  # => 'joeblogs'
        # 
        # Note! returns 'not audited' if there's no audited version (new unsaved record)
        # 
        def last_audited_at
          v = versions.last unless versions.empty?
          v ? v.created_at : 'not audited'
        end
        alias_method :last_audited_on, :last_audited_at

        # return previous version of object
        #   steps_back - number of steps back from current version(0 - is current version)
        def previous_version(steps_back = 0)
          if versions.any?
            # get version +number+ which we will had when move user to number of steps which he choose
            step_back_version_number = versions.last.version - (steps_back + 1)

            # If user set too much steps back then return +nil+,
            # because correct version of current object will not be found.
            if step_back_version_number >= 0

              # get object by number from previous operation
              current_version = versions.where{version > step_back_version_number}.first

              # +changed+ field contains JSON object which is looks like:
              #   {price: [1, 2], discount: [5, 10]}
              #
              #   +key+ is a field what was changed
              #   +value+ is an Array where:
              #     - first element is old_value
              #     - second element is a new_value
              #
              # So we collect only old values and set it to temporary duplicated object of current object.
              old_values = JSON.parse(current_version.changed, symbolize_names: true).inject({}) do |result, (key, value)|
                result.merge!(key => value.first)
              end

              # Duplicate current object to have ability to check step_back version
              # without object attributes overriding.
              temp_object = self.dup
              temp_object.values.merge!(old_values)
              temp_object.define_singleton_method(:version_number) { step_back_version_number }
              temp_object
            end
          end
        end

        # turn back current object to previous version
        #   steps_back - number of steps back from current version(0 - is current version)
        def previous_version!(steps_back = 0)
          prev_version = previous_version(steps_back)

          prev_version.save if prev_version.present?
        end

        private

        # extract audited values only
        def extract_audited_values(default_values)
          default_values.slice(*self.class.audited_columns)
        end

        ### CALLBACKS ###

        def after_create
          super
          changed =  self.values
          new_values = extract_audited_values(changed)
          # :user, :version & :created_at set in model
          if new_values.present?
            add_version(
              model_type: model,
              model_pk:   pk,
              event:      'create',
              changed:    new_values.to_json
            )
          end
        end

        def after_update
          super
          changed = column_changes.empty? ? previous_changes : column_changes
          new_values = extract_audited_values(changed)
          # :user, :version & :created_at set in model
          if new_values.present?
            add_version(
              model_type:  model,
              model_pk:    pk,
              event:       'update',
              changed:     new_values.to_json
            )
          end

          # If object respond_to?(:version_number) then it means that
          # we have duplication object from +previous_version+ method.
          if respond_to?(:version_number)
            till_version = self.version_number

            versions.each do |audited_version|
              remove_version(audited_version) if audited_version.version > till_version
            end
          end
        end

        def after_destroy
          super
          changed =  self.values
          new_values = extract_audited_values(changed)
          # :user, :version & :created_at set in model
          if new_values.present?
            add_version(
              model_type:  model,
              model_pk:    pk,
              event:       'destroy',
              changed:     new_values.to_json
            )
          end
        end
      end
    end
  end
end
