require 'bundler/gem_tasks'
require 'fileutils'

desc "Clear VCR cassettes"
task "clear_vcr_cassettes" do
  force_delete = true
  FileUtils.remove_dir('spec/fixtures/VCR')
  FileUtils.remove_dir('spec/fixtures/A_Yieldmanager_client')
  FileUtils.remove_dir('spec/fixtures/A_Yieldmanager_report_request')
end
