# name: GitHub badges
# about: Assign users badges based on GitHub contributions
# version: 0.1
# authors: Sam Saffron

module ::GithubBadges
  def self.badge_grant!

    return unless SiteSetting.github_badges_repo.present?

    # ensure badges exist
    unless bronze = Badge.find_by(name: 'Contributor')
      bronze = Badge.create!(name: 'Contributor',
                             description: 'contributed an accepted pull request',
                             badge_type_id: 3)
    end

    unless silver = Badge.find_by(name: 'Great contributor')
      silver = Badge.create!(name: 'Great contributor',
                             description: 'contributed 25 accepted pull request',
                             badge_type_id: 2)
    end

    unless gold = Badge.find_by(name: 'Amazing contributor')
      gold = Badge.create!(name: 'Amazing contributor',
                             description: 'contributed 250 accepted pull request',
                             badge_type_id: 1)
    end

    emails = []

    path = '/tmp/github_badges'

    if !Dir.exists?(path)
      Rails.logger.info `cd /tmp && git clone #{SiteSetting.github_badges_repo} github_badges`
    else
      Rails.logger.info `cd #{path} && git pull`
    end

    `cd #{path} && git log --merges --pretty=format:%p --grep='Merge pull request'`.each_line do |m|
      emails << (`cd #{path} && git log -1 --format=%ce #{m.split(' ')[1].strip}`.strip)
    end

    email_commits = emails.group_by{|e| e}.map{|k, l|[k,l.count]}

    Rails.logger.info "#{email_commits.length} commits found!"

    email_commits.each do |email, commits|
      user = User.find_by(email: email)

      if user
        if commits < 25
          BadgeGranter.grant(bronze, user)
          if user.title.blank?
            user.title = bronze.name
            user.save
          end
        elsif commits < 250
          BadgeGranter.grant(silver, user)
          if user.title.blank?
            user.title = silver.name
            user.save
          end
        else
          BadgeGranter.grant(gold, user)
          if user.title.blank?
            user.title = gold.name
            user.save
          end
        end
      end

    end

  end
end

after_initialize do
  module ::GithubBadges
    class UpdateJob < ::Jobs::Scheduled
      every 1.day

      def execute(args)
        GithubBadges.badge_grant!
      end
    end
  end
end
