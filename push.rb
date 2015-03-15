#! /usr/bin/env ruby

require 'json'
require 'algoliasearch'
require 'open-uri'
require 'pry'
require 'oj'
require 'money'

def create_index(jobs)
  index = Algolia::Index.new(ARGV[2])
  index.set_settings :attributesToIndex => ["JobTitle", "Locations", "JobSummary", "WorkSchedule", "WorkType", "OrganizationName"],
                     :attributesForFaceting => ["WorkType", "WorkSchedule", "OrganizationName", "Locations", "SalaryMin", "StartDate", "EndDate", "customerReviewCount", "salary"],
                     :slaves => ["#{ARGV[2]}_salary_desc", "#{ARGV[2]}_salary_asc"]
  index.clear_index! rescue 'not fatal'
  res = index.add_objects jobs
  index.wait_task res['taskID']

  Algolia::Index.new("#{ARGV[2]}_salary_desc").set_settings :attributesToIndex => ["JobTitle", "Locations", "JobSummary", "WorkSchedule", "WorkType", "OrganizationName"],
                                                            :attributesForFaceting => ["WorkType", "WorkSchedule", "OrganizationName", "Locations", "SalaryMin", "StartDate", "EndDate", "customerReviewCount", "salary"],
                                                            :ranking => ["desc(salary)", "typo", "geo", "words", "proximity", "attribute", "exact", "custom"]

  Algolia::Index.new("#{ARGV[2]}_salary_asc").set_settings :attributesToIndex => ["JobTitle", "Locations", "JobSummary", "WorkSchedule", "WorkType", "OrganizationName"],
                                                           :attributesForFaceting => ["WorkType", "WorkSchedule", "OrganizationName", "Locations", "SalaryMin", "StartDate", "customerReviewCount", "salary"],
                                                           :ranking => ["asc(salary)", "typo", "geo", "words", "proximity", "attribute", "exact", "custom"]
end

# Use with: source env.sh
# ruby push.rb $ALGOLIA_APP_ID $ALGOLIA_ADMIN_API_KEY ujt
if ARGV.length != 3
  $stderr << "usage: push.rb APPLICATION_ID API_KEY INDEX\n"
  exit 1
end
data = Oj.load(File.read('./data.json'))
jobs = data.map do |e|
  e['JobData'].map do |job_entry|
    job_entry['salary'] = Money.parse(job_entry['SalaryMin']).to_f.to_i
    job_entry
  end
end.reduce(:+)
Algolia.init :application_id => ARGV[0], :api_key => ARGV[1]
create_index(jobs)
