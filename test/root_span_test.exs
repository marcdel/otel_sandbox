defmodule RootSpanTest do
  use ExUnit.Case

  require OpenTelemetry.Tracer
  require OpenTelemetry.Span

  # Make span methods available
  require Record

  for {name, spec} <- Record.extract_all(from_lib: "opentelemetry/include/ot_span.hrl") do
    Record.defrecord(name, spec)
  end

  @always_on_sampler :ot_sampler.setup(:always_on, %{})
  @always_off_sampler :ot_sampler.setup(:always_off, %{})
  @zero_percent_sampler :ot_sampler.setup(:probability, %{probability: 0.0})
  @one_hundred_percent_sampler :ot_sampler.setup(:probability, %{probability: 1.0})

  setup :telemetry_pid_exporter

  test "everything is exported by default" do
    Enum.map(1..4, fn i ->
      OpenTelemetry.Tracer.with_span "span#{i}" do
      end
    end)

    assert_receive {:span, span(name: "span1")}
    assert_receive {:span, span(name: "span2")}
    assert_receive {:span, span(name: "span3")}
    assert_receive {:span, span(name: "span4")}
  end

  describe "always_on/off" do
    test "when off, spans are not exported" do
      Enum.map(1..4, fn i ->
        OpenTelemetry.Tracer.with_span "span#{i}", %{sampler: @always_off_sampler} do
        end
      end)

      refute_receive {:span, span(name: "span1")}
      refute_receive {:span, span(name: "span2")}
      refute_receive {:span, span(name: "span3")}
      refute_receive {:span, span(name: "span4")}
    end

    test "when on, spans are exported" do
      Enum.map(1..4, fn i ->
        OpenTelemetry.Tracer.with_span "span#{i}", %{sampler: @always_on_sampler} do
        end
      end)

      assert_receive {:span, span(name: "span1")}
      assert_receive {:span, span(name: "span2")}
      assert_receive {:span, span(name: "span3")}
      assert_receive {:span, span(name: "span4")}
    end
  end

  describe "percentage" do
    test "when off, spans are not exported" do
      Enum.map(1..4, fn i ->
        OpenTelemetry.Tracer.with_span "span#{i}", %{sampler: @zero_percent_sampler} do
        end
      end)

      refute_receive {:span, span(name: "span1")}
      refute_receive {:span, span(name: "span2")}
      refute_receive {:span, span(name: "span3")}
      refute_receive {:span, span(name: "span4")}
    end

    test "when on, spans are exported" do
      Enum.map(1..4, fn i ->
        OpenTelemetry.Tracer.with_span "span#{i}", %{sampler: @one_hundred_percent_sampler} do
        end
      end)

      assert_receive {:span, span(name: "span1")}
      assert_receive {:span, span(name: "span2")}
      assert_receive {:span, span(name: "span3")}
      assert_receive {:span, span(name: "span4")}
    end
  end

  def telemetry_pid_exporter(_ \\ []) do
    ExUnit.CaptureLog.capture_log(fn -> :application.stop(:opentelemetry) end)

    :application.set_env(:opentelemetry, :tracer, :ot_tracer_default)

    :application.set_env(:opentelemetry, :processors, [
      {:ot_batch_processor, %{scheduled_delay_ms: 1}}
    ])

    :application.start(:opentelemetry)

    :ot_batch_processor.set_exporter(:ot_exporter_pid, self())

    :ok
  end
end
