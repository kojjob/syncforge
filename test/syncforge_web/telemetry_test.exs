defmodule SyncforgeWeb.TelemetryTest do
  use ExUnit.Case, async: true

  alias SyncforgeWeb.Telemetry

  describe "metrics/0" do
    test "includes SyncForge custom metrics" do
      metric_names = Telemetry.metrics() |> Enum.map(& &1.name)

      # Custom room metrics
      assert [:syncforge, :room, :join, :count] in metric_names
      assert [:syncforge, :room, :leave, :count] in metric_names
      assert [:syncforge, :channel, :message, :count] in metric_names

      # Presence and active room gauges
      assert [:syncforge, :presence, :tracked_users, :count] in metric_names
      assert [:syncforge, :rooms, :active_count, :count] in metric_names
    end

    test "includes standard Phoenix metrics" do
      metric_names = Telemetry.metrics() |> Enum.map(& &1.name)

      assert [:phoenix, :endpoint, :stop, :duration] in metric_names
      assert [:phoenix, :router_dispatch, :stop, :duration] in metric_names
    end

    test "includes database metrics" do
      metric_names = Telemetry.metrics() |> Enum.map(& &1.name)

      assert [:syncforge, :repo, :query, :total_time] in metric_names
    end

    test "channel message metric has event tag" do
      channel_msg_metric =
        Telemetry.metrics()
        |> Enum.find(fn m -> m.name == [:syncforge, :channel, :message, :count] end)

      assert :event in channel_msg_metric.tags
    end
  end

  describe "emit_room_join/1 and emit_room_leave/1" do
    test "emit_room_join emits telemetry event" do
      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:syncforge, :room, :join]
        ])

      Telemetry.emit_room_join(%{room_id: "test-room-123"})

      assert_received {[:syncforge, :room, :join], ^ref, %{count: 1}, %{room_id: "test-room-123"}}
    end

    test "emit_room_leave emits telemetry event" do
      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:syncforge, :room, :leave]
        ])

      Telemetry.emit_room_leave(%{room_id: "test-room-456"})

      assert_received {[:syncforge, :room, :leave], ^ref, %{count: 1},
                       %{room_id: "test-room-456"}}
    end
  end

  describe "emit_channel_message/1" do
    test "emits telemetry event with event name" do
      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:syncforge, :channel, :message]
        ])

      Telemetry.emit_channel_message(%{event: "cursor:update", room_id: "room-1"})

      assert_received {[:syncforge, :channel, :message], ^ref, %{count: 1},
                       %{event: "cursor:update", room_id: "room-1"}}
    end
  end
end
