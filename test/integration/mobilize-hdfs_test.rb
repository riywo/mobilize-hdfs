require 'test_helper'
describe "Mobilize" do
  # enqueues 4 workers on Resque
  it "runs integration test" do

    puts "restart workers"
    Mobilize::Jobtracker.restart_workers!

    u = TestHelper.owner_user
    r = u.runner
    user_name = u.name
    gdrive_slot = u.email

    puts "add test data"
    ["hdfs1.in"].each do |fixture_name|
      target_url = "gsheet://#{r.title}/#{fixture_name}"
      TestHelper.write_fixture(fixture_name, target_url, 'replace')
    end

    puts "add/update jobs"
    u.jobs.each{|j| j.stages.each{|s| s.delete}; j.delete}
    jobs_fixture_name = "integration_jobs"
    jobs_target_url = "gsheet://#{r.title}/jobs"
    TestHelper.write_fixture(jobs_fixture_name, jobs_target_url, 'update')

    puts "job rows added, force enqueue runner, wait for stages"
    #wait for stages to complete
    expected_fixture_name = "integration_expected"
    Mobilize::Jobtracker.stop!
    r.enqueue!
    TestHelper.confirm_expected_jobs(expected_fixture_name)

    puts "update job status and activity"
    r.update_gsheet(gdrive_slot)

    puts "check posted data"
    ['hdfs1_copy.out'].each do |out_name|
      url = "gsheet://#{r.title}/#{out_name}"
      assert TestHelper.check_output(url, 'min_length' => 599) == true
    end
  end
end
