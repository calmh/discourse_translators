# name: Transifex translators
# about: Assign users badges based on translation contributions
# version: 0.1
# authors: Sam Saffron

  require 'net/http'
require 'json'

module ::TransifexTranslators
  def self.translators
    url = URI.parse('http://www.transifex.com/api/2/project/' + SiteSetting.transifex_translators_project + '/languages/')
    req = Net::HTTP::Get.new(url.to_s)
    req.basic_auth SiteSetting.transifex_translators_user, SiteSetting.transifex_translators_pass
    res = Net::HTTP.start(url.host, url.port) {|http|
      http.request(req)
    }
    data = JSON.parse(res.body)

    users = []
    data.each do |lang|
      users.concat lang['coordinators'] + lang['reviewers'] + lang['translators']
    end
    users.uniq
  end

  def self.badge_grant!

    return unless SiteSetting.transifex_translators_project.present?

    unless bronze = Badge.find_by(name: 'Translator')
      bronze = Badge.create!(name: 'Translator',
                             description: 'Contributes translations',
                             badge_type_id: 3)
    end

    self.translators.each do |name|
      user = User.find_by(username: name)

      if user
        BadgeGranter.grant(bronze, user)
      end
    end
  end
end

after_initialize do
  module ::TransifexTranslators
    class UpdateJob < ::Jobs::Scheduled
      every 1.day

      def execute(args)
        TransifexTranslators.badge_grant!
      end
    end
  end
end
