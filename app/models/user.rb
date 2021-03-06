class User < ApplicationRecord
  has_many :projects
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable,
         :omniauthable, :omniauth_providers => [:github]

  SOCIALS_NETWORKING = {
      linkedin: 'linkedin.com/in',
      angellist: 'angel.co',
      twitter: 'twitter.com',
      facebook: 'facebook.com',
      google_plus: 'plus.google.com'
  }

  SOCIALS_DEVELOPMENT = {
      stack_overflow: 'stackoverflow.com/users',
      codepen: 'codepen.io',
      jsfiddle: 'jsfiddle.net'
  }

  SOCIALS_WRITING = {
      medium: 'medium.com',
      blog: ''
  }

  SOCIALS_DESIGN = {
      behance: 'behance.net',
      dribbble: 'dribbble.com',
      pinterest: 'pinterest.com'
  }

  GROUPED_SOCIALS = [
      [:networking, SOCIALS_NETWORKING],
      [:writing, SOCIALS_WRITING],
      [:development, SOCIALS_DEVELOPMENT],
      [:design, SOCIALS_DESIGN]
  ]

  HASH_SOCIALS = GROUPED_SOCIALS.flat_map { |group| group[1].map { |social| [social[0], social[1]] } }.to_h
  SOCIALS = HASH_SOCIALS.flat_map { |social, _| social }

  def first_name
    self.display_name.split(' ')[0]
  end

  def display_name
    self.name || self.username
  end

  def linkedin=(val)
    set_social(:linkedin, val)
  end

  def angellist=(val)
    set_social(:angellist, val)
  end

  def facebook=(val)
    set_social(:facebook, val)
  end

  def twitter=(val)
    set_social(:twitter, val)
  end

  def google_plus=(val)
    set_social(:google_plus, val)
  end

  def medium=(val)
    set_social(:medium, val)
  end

  def stack_overflow=(val)
    set_social(:stack_overflow, val)
  end

  def codepen=(val)
    set_social(:codepen, val)
  end

  def jsfiddle=(val)
    set_social(:jsfiddle, val)
  end

  def behance=(val)
    set_social(:behance, val)
  end

  def dribbble=(val)
    set_social(:dribbble, val)
  end

  def pinterest=(val)
    set_social(:pinterest, val)
  end

  def social(key)
    User.social(key, self[key])
  end

  def self.social(key, value)
    return value if value.include?('http://') or value.include?('https://')

    pre = HASH_SOCIALS[key] ? "#{HASH_SOCIALS[key]}/" : ''
    "https://#{pre}#{value}"
  end

  def socials
    result = {}
    result['github'] = "github.com/#{self.username}"

    User::SOCIALS.each do |social|
      result[social] = self[social] unless self[social].to_s.empty?
    end

    result
  end

  def self.create_from_github(auth)
    user = User.new
    user.email = auth.info.email
    user.password = Devise.friendly_token[0, 20]
    user.github_uid = auth.uid
    user.github_token = auth.credentials.token
    user.role = 'Jedi Developer'

    user.sync_profile
    user
  end

  def sync
    sync_profile
    sync_skills_projects
  end

  def sync_profile
    git_user = client.user

    self.avatar = git_user.avatar_url

    # Add suggested size to avoid undesired big preview images
    if self.avatar.include?('?') and !self.avatar.include?('&s=')
      self.avatar << '&s=400'
    end

    self.username = git_user.login.to_s.downcase
    self.name = git_user.name
    self.website = git_user.blog if git_user.blog.present?
    self.location = git_user.location if git_user.location.present?
    self.email = git_user.email if git_user.email.present?
    self.hireable = git_user.hireable
    self.bio = git_user.bio if git_user.bio.present?

    self.company = git_user.company
    self.company_website = 'https://github.com/' + self.company[1..-1] if self.company.present? and self.company[0] == '@'

    save!
  end

  def sync_skills_projects
    result = []

    client.repositories.each do |repository|
      project = projects.where(repository: repository.full_name).first

      unless project
        project = projects.new(repository: repository.full_name, position: 1)
        project.sync(repository)

        result.push project

        if project.language.present?
          self.skills = {} unless self.skills
          self.skills[project.language] = 3 unless self.skills[project.language]
        end
      end
    end

    if self.website and not projects.where(homepage: self.website).first
      website_project = projects.new(homepage: self.website)
      website_project.sync_homepage
      website_project.position = 0
      result.push website_project
    end

    save!
    result
  end

  def website_url
    return nil unless self.website.present?
    (self.website.include?('http://') or self.website.include?('https://')) ? self.website : "http://#{self.website}"
  end

  def company_website_url
    return nil unless self.company_website.present?
    (self.company_website.include?('http://') or self.company_website.include?('https://')) ?
        self.company_website :
        "http://#{self.company_website}"
  end

  def update_skills(skills)
    parsed = {}

    skills.each do |name, mastery|
      parsed[name] = mastery.to_i
    end

    self.update({skills: parsed})
  end

  private

  def client
    @client ||= Octokit::Client.new(:access_token => self.github_token)
  end

  def set_social(key, value)
    pre = HASH_SOCIALS[key]
    self[key] = value.sub(/^https?\:\/\//, '').sub(/^www./, '').sub(pre, '')
  end
end
