# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Kubernetes::ResourceStatus do
  let(:status) do
    Kubernetes::ResourceStatus.new(
      deploy_group: deploy_groups(:pod1),
      role: kubernetes_roles(:app_server),
      resource: resource,
      kind: resource.fetch(:kind),
      start: Time.now.iso8601
    )
  end
  let(:resource) { {kind: 'Pod', metadata: {name: 'foo', namespace: 'default'}, status: {phase: "Running"}} }
  let(:events) { [{lastTimestamp: 30.seconds.from_now.utc.iso8601}] }

  describe "#check" do
    let(:details) do
      status.check
      status.details
    end

    it "does not provide details for non-pods" do
      resource[:kind] = "Service"
      details.must_be_nil
    end

    it "is missing without resource" do
      status.instance_variable_set(:@resource, nil)
      details.must_equal "Missing"
    end

    it "is restarted when pod is restarted" do
      resource[:status][:containerStatuses] = [{restartCount: 1}]
      details.must_equal "Restarted"
    end

    it "is failed when pod is failed" do
      resource[:status][:phase] = "Failed"
      details.must_equal "Failed"
    end

    it "is live when live" do
      resource[:status][:phase] = "Succeeded"
      details.must_equal "Live"
    end

    it "is live when complete and prerequisite" do
      resource[:status][:phase] = "Succeeded"
      status.instance_variable_set(:@prerequisite, true)
      details.must_equal "Live"
    end

    it "is waiting" do
      assert_request :get, /events/, to_return: {body: {items: []}.to_json} do
        details.must_equal "Waiting (Running, Unknown)"
      end
    end

    it "waits when resources are missing" do
      events[0].merge!(type: "Warning", reason: "FailedScheduling")
      assert_request :get, /events/, to_return: {body: {items: events}.to_json} do
        details.must_equal "Waiting for resources (Running, Unknown)"
      end
    end

    it "errors when bad events happen" do
      events[0].merge!(type: "Warning", reason: "Boom")
      assert_request :get, /events/, to_return: {body: {items: events}.to_json} do
        details.must_equal "Error event"
      end
    end
  end

  describe "#events" do
    let(:result) do
      assert_request :get, /events/, to_return: {body: {items: events}.to_json} do
        status.events
      end
    end

    it "finds events" do
      result.size.must_equal 1
    end

    it "ignores previous events" do
      events.first[:lastTimestamp] = 30.seconds.ago.utc.iso8601
      result.size.must_equal 0
    end

    it "sorts" do
      new = 60.seconds.from_now.utc.iso8601
      events.unshift lastTimestamp: new
      events.push lastTimestamp: new
      result.first.must_equal events[1]
    end
  end
end
