# frozen_string_literal: true

require_relative '../../test_helper'

SingleCov.covered!

describe Samson::TimeSum do
  describe ".record" do
    it "records empty" do
      calls = []
      Samson::TimeSum.record({}) { calls << 1 }.keys.must_equal []
      calls.must_equal [1]
    end

    it "records single" do
      result = Samson::TimeSum.record("sql.active_record" => :db) { User.first }
      result.keys.must_equal [:db]
      assert result[:db].between?(0, 5), result
    end

    it "records 0 when nothing happened" do
      calls = []
      Samson::TimeSum.record("sql.active_record" => :db) { calls << 1 }[:db].must_equal 0
      calls.must_equal [1]
    end
  end

  describe ".instrument" do
    it "logs" do
      Rails.logger.expects(:info).with do |payload|
        payload[:message].must_equal "Job execution finished"
        assert payload[:parts][:db].between?(0, 5)
        true
      end
      result = Samson::TimeSum.instrument("execute_job.samson", project: "foo", stage: "bar", production: false) do
        User.first
      end
      result.must_equal User.first
    end

    it "does not log parts when crashing" do
      Rails.logger.expects(:info).with do |payload|
        payload[:message].must_equal "Job execution finished"
        refute payload[:parts]
        true
      end
      assert_raises ArgumentError do
        Samson::TimeSum.instrument("execute_job.samson", project: "foo", stage: "bar", production: false) do
          raise ArgumentError
        end
      end
    end
  end
end
