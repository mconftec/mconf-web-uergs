namespace :setup do
  task :populate => 'populate:create'

  namespace :populate do

    desc "Reload populate data"
    task :reload => [ 'setup:basic_data:reload', 'setup:populate' ]

    desc "Erase non basic data and fill database"
    task :create => :environment do
      require 'populator'
      require 'faker'

      # DESTROY #
      [ Space ].each(&:destroy_all)
      # Delete all users except Admin
      users_without_admin = User.find_with_disabled(:all)
      users_without_admin.delete(User.find_by_login("vcc"))
      users_without_admin.each(&:destroy)


      puts "* Create Users"
      User.populate 15 do |user|
        user.login = Populator.words(1)
        user.email = Faker::Internet.email
        user.crypted_password = User.encrypt("test", "")
        user.activated_at = 2.years.ago..Time.now
        user.disabled = false
        user.notification = User::NOTIFICATION_VIA_EMAIL
        
        Profile.populate 1 do |profile|
          profile.user_id = user.id
          profile.full_name = Faker::Name.name
          profile.organization = Populator.words(1..3).titleize
          profile.phone = Faker::PhoneNumber.phone_number
          profile.mobile = Faker::PhoneNumber.phone_number
          profile.fax = Faker::PhoneNumber.phone_number
          profile.address = Faker::Address.street_address
          profile.city = Faker::Address.city
          profile.zipcode = Faker::Address.zip_code
          profile.province = Faker::Address.uk_county
          profile.country = Faker::Address.uk_country
          profile.prefix_key = Faker::Name.prefix
          profile.description = Populator.sentences(1..3)
          profile.url = "http://" + Faker::Internet.domain_name + "/" + Populator.words(1)
          profile.skype = Populator.words(1)
          profile.im = Faker::Internet.email
          profile.visibility = Populator.value_in_range((Profile::VISIBILITY.index(:everybody))..(Profile::VISIBILITY.index(:nobody)))
        end
      end

      puts "* Create Spaces"
      Space.populate 20 do |space|
        space.name = Populator.words(1..3).titleize
        space.permalink = PermalinkFu.escape(space.name)
        space.description = Populator.sentences(1..3)
        space.public = [ true, false ]
        space.disabled = false

        Post.populate 10..100 do |post|
          post.space_id = space.id
          post.title = Populator.words(1..4).titleize
          post.text = Populator.sentences(3..15)
          post.spam = false
          post.created_at = 2.years.ago..Time.now
          post.updated_at = post.created_at..Time.now
  #        post.tag_with Populator.words(1..4).gsub(" ", ",")
        end

        Event.populate 5..10 do |event|
          event.space_id = space.id
          event.name = Populator.words(1..3).titleize
          event.description = Populator.sentences(0..3)
          event.place = Populator.sentences(0..2)
          event.spam = false
          event.created_at = 1.years.ago..Time.now
          event.updated_at = event.created_at..Time.now
          event.start_date = event.created_at..1.years.since(Time.now)
          event.end_date = 2.hours.since(event.start_date)..2.days.since(event.start_date)
          event.vc_mode = Event::VC_MODE.index(:in_person)
          event.permalink = PermalinkFu.escape(event.name)
          
          Agenda.populate 1 do |agenda|
            agenda.event_id = event.id
            agenda.created_at = event.created_at..Time.now
            agenda.updated_at = agenda.created_at..Time.now
            
            # inferior limit for the start time of the first agenda entry
            last_agenda_entry_end_time = event.start_date
            
            AgendaEntry.populate 2..10 do |agenda_entry|
              agenda_entry.agenda_id = agenda.id
              agenda_entry.title = Populator.words(1..3).titleize
              agenda_entry.description = Populator.sentences(0..2)
              agenda_entry.speakers = Populator.words(2..6).titleize
              agenda_entry.start_time = last_agenda_entry_end_time..event.end_date
              agenda_entry.end_time = agenda_entry.start_time..event.end_date
             
              # updating the inferior limit for the next agenda entry
              last_agenda_entry_end_time = agenda_entry.end_time

              agenda_entry.created_at = agenda.created_at..Time.now
              agenda_entry.updated_at = agenda_entry.created_at..Time.now
              agenda_entry.embedded_video = "<object width='425' height='344'><param name='movie' " +
                "value='http://www.youtube.com/v/9ri3y2RDzUM&hl=es_ES&fs=1&'></param><param name='allowFullScreen'" +
                " value='true'></param><param name='allowscriptaccess' value='always'></param><embed" +
                " src='http://www.youtube.com/v/9ri3y2RDzUM&hl=es_ES&fs=1&' type='application/x-shockwave-flash'" +
                " allowscriptaccess='always' allowfullscreen='true' width='425' height='344'></embed></object>"
              agenda_entry.video_thumbnail = "http://i2.ytimg.com/vi/9ri3y2RDzUM/default.jpg"
            end
          end
        end

        Group.populate 2..4 do |group|
          group.space_id = space.id
          group.name = Populator.words(1..3).titleize
        end

        News.populate 2..15 do |news|
          news.space_id = space.id
          news.title = Populator.words(3..8).titleize
          news.text = Populator.sentences(2..10)
          news.created_at = 2.years.ago..Time.now
          news.updated_at = news.created_at..Time.now
        end
      end

      users = User.all
      role_ids = Role.find_all_by_stage_type('Space').map(&:id)

      Space.all.each do |space|
        available_users = users.dup

        Performance.populate 5..7 do |performance|
          user = available_users.delete_at((rand * available_users.size).to_i)
          performance.stage_id = space.id
          performance.stage_type = 'Space'
          performance.role_id = role_ids
          performance.agent_id = user.id
          performance.agent_type = 'User'
        end

        space.groups.each do |group|
          space.users.each do |user|
            next if user.is_a?(SingularAgent)
            group.users << user if rand > 0.7
          end
        end
        
        space.events.each do |event|
          available_event_participants = space.users.dup
          Participant.populate 0..space.users.count do |participant|
            participant_aux = available_event_participants.delete_at((rand * available_event_participants.size).to_i)
            participant.user_id = participant_aux.id
            participant.email = participant_aux.email
            participant.event_id = event.id
            participant.created_at = event.created_at..Time.now
            participant.updated_at = participant.created_at..Time.now
            participant.attend = (rand(0) > 0.5)

            Performance.populate 1 do |performance|
              performance.stage_id = event.id
              performance.stage_type = 'Event'
              performance.role_id = role_ids
              performance.agent_id = participant.user_id
              performance.agent_type = 'User'
            end
          end
        end

      end

      Post.record_timestamps = false

      # Posts.parent_id
      Space.all.each do |space|
        total_posts = space.posts.dup
        # The first Post should not have parent
        final_posts = Array.new << total_posts.shift

        total_posts.inject final_posts do |posts, post|
          parent = posts[(rand * posts.size).to_i]
          unless parent.parent_id
            post.update_attribute :parent_id, parent.id
          end

          posts << post
        end

        # Author
        ( space.posts + space.events ).each do |item|
          item.author = space.users.rand
          # Save the items without performing validations, to allow further testing
          item.save(false)
        end

      end
      
      Site.find(1).update_attribute(:signature, "VCC")
      
    end
  end
end
