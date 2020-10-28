defmodule ParentChildTest do
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

  @sampler1 :ot_sampler.setup(:probability, %{probability: 0.1})
  @sampler2 :ot_sampler.setup(:probability, %{probability: 0.1, ignore_parent_flag: true})
  @sampler3 :ot_sampler.setup(:probability, %{probability: 0.1, ignore_parent_flag: false})
  @sampler4 :ot_sampler.setup(:probability, %{probability: 0.1, only_rootel_spans: true})
  @sampler5 :ot_sampler.setup(:probability, %{probability: 0.1, only_rootel_spans: false})
  @sampler6 :ot_sampler.setup(:probability, %{
              probability: 0.1,
              ignore_parent_flag: false,
              only_rootel_spans: false
            })
  @sampler7 :ot_sampler.setup(:probability, %{
              probability: 0.1,
              ignore_parent_flag: true,
              only_rootel_spans: true
            })
  @sampler8 :ot_sampler.setup(:probability, %{
              probability: 0.1,
              ignore_parent_flag: false,
              only_rootel_spans: true
            })
  @sampler9 :ot_sampler.setup(:probability, %{
              probability: 0.1,
              ignore_parent_flag: true,
              only_rootel_spans: false
            })

  setup :telemetry_pid_exporter

  test "everything is exported by default" do
    telemetry_pid_exporter()

    OpenTelemetry.Tracer.with_span "parent" do
      Enum.map(1..4, fn i ->
        OpenTelemetry.Tracer.with_span "child#{i}" do
        end
      end)
    end

    assert_receive {:span, span(name: "parent")}
    assert_receive {:span, span(name: "child1")}
    assert_receive {:span, span(name: "child2")}
    assert_receive {:span, span(name: "child3")}
    assert_receive {:span, span(name: "child4")}
  end

  describe "always_on/off" do
    test "when parent is off, and children are not set: parent and children are not exported" do
      OpenTelemetry.Tracer.with_span "parent", %{sampler: @always_off_sampler} do
        Enum.map(1..4, fn i ->
          OpenTelemetry.Tracer.with_span "child#{i}" do
          end
        end)
      end

      refute_receive {:span, span(name: "parent")}
      refute_receive {:span, span(name: "child1")}
      refute_receive {:span, span(name: "child2")}
      refute_receive {:span, span(name: "child3")}
      refute_receive {:span, span(name: "child4")}
    end

    test "when parent is on, but children are off: parent is exported, children are not" do
      OpenTelemetry.Tracer.with_span "parent", %{sampler: @always_on_sampler} do
        Enum.map(1..4, fn i ->
          OpenTelemetry.Tracer.with_span "child#{i}", %{sampler: @always_off_sampler} do
          end
        end)
      end

      assert_receive {:span, span(name: "parent")}
      refute_receive {:span, span(name: "child1")}
      refute_receive {:span, span(name: "child2")}
      refute_receive {:span, span(name: "child3")}
      refute_receive {:span, span(name: "child4")}
    end

    test "when parent is off, but children are on: parent is not exported, but children are" do
      OpenTelemetry.Tracer.with_span "parent", %{sampler: @always_off_sampler} do
        Enum.map(1..4, fn i ->
          OpenTelemetry.Tracer.with_span "child#{i}", %{sampler: @always_on_sampler} do
          end
        end)
      end

      refute_receive {:span, span(name: "parent")}
      assert_receive {:span, span(name: "child1")}
      assert_receive {:span, span(name: "child2")}
      assert_receive {:span, span(name: "child3")}
      assert_receive {:span, span(name: "child4")}
    end

    test "when parent is not set, and children are on, parent and children are exported" do
      OpenTelemetry.Tracer.with_span "parent" do
        Enum.map(1..4, fn i ->
          OpenTelemetry.Tracer.with_span "child#{i}", %{sampler: @always_on_sampler} do
          end
        end)
      end

      assert_receive {:span, span(name: "parent")}
      assert_receive {:span, span(name: "child1")}
      assert_receive {:span, span(name: "child2")}
      assert_receive {:span, span(name: "child3")}
      assert_receive {:span, span(name: "child4")}
    end

    test "when parent is not set, and children are off, parent is exported but children are not" do
      OpenTelemetry.Tracer.with_span "parent" do
        Enum.map(1..4, fn i ->
          OpenTelemetry.Tracer.with_span "child#{i}", %{sampler: @always_off_sampler} do
          end
        end)
      end

      assert_receive {:span, span(name: "parent")}
      refute_receive {:span, span(name: "child1")}
      refute_receive {:span, span(name: "child2")}
      refute_receive {:span, span(name: "child3")}
      refute_receive {:span, span(name: "child4")}
    end
  end

  describe "percentage" do
    test "when parent is percentage, and children are not set: parent and children use percentage" do
      OpenTelemetry.Tracer.with_span "parent", %{sampler: @zero_percent_sampler} do
        Enum.map(1..4, fn i ->
          OpenTelemetry.Tracer.with_span "child#{i}" do
          end
        end)
      end

      refute_receive {:span, span(name: "parent")}
      refute_receive {:span, span(name: "child1")}
      refute_receive {:span, span(name: "child2")}
      refute_receive {:span, span(name: "child3")}
      refute_receive {:span, span(name: "child4")}
    end

    test "when parent is on, but children are off: parent is exported, children are not" do
      OpenTelemetry.Tracer.with_span "parent", %{sampler: @one_hundred_percent_sampler} do
        Enum.map(1..4, fn i ->
          OpenTelemetry.Tracer.with_span "child#{i}", %{sampler: @zero_percent_sampler} do
          end
        end)
      end

      assert_receive {:span, span(name: "parent")}
      refute_receive {:span, span(name: "child1")}
      refute_receive {:span, span(name: "child2")}
      refute_receive {:span, span(name: "child3")}
      refute_receive {:span, span(name: "child4")}
    end

    test "when parent is off, but children are on: parent is not exported, but children are" do
      OpenTelemetry.Tracer.with_span "parent", %{sampler: @zero_percent_sampler} do
        Enum.map(1..4, fn i ->
          OpenTelemetry.Tracer.with_span "child#{i}", %{sampler: @one_hundred_percent_sampler} do
          end
        end)
      end

      refute_receive {:span, span(name: "parent")}
      assert_receive {:span, span(name: "child1")}
      assert_receive {:span, span(name: "child2")}
      assert_receive {:span, span(name: "child3")}
      assert_receive {:span, span(name: "child4")}
    end

    test "when parent is not set, and children are on, parent and children are exported" do
      OpenTelemetry.Tracer.with_span "parent" do
        Enum.map(1..4, fn i ->
          OpenTelemetry.Tracer.with_span "child#{i}", %{sampler: @one_hundred_percent_sampler} do
          end
        end)
      end

      assert_receive {:span, span(name: "parent")}
      assert_receive {:span, span(name: "child1")}
      assert_receive {:span, span(name: "child2")}
      assert_receive {:span, span(name: "child3")}
      assert_receive {:span, span(name: "child4")}
    end

    test "when parent is not set, and children are off, parent is exported but children are not" do
      OpenTelemetry.Tracer.with_span "parent" do
        Enum.map(1..4, fn i ->
          OpenTelemetry.Tracer.with_span "child#{i}", %{sampler: @zero_percent_sampler} do
          end
        end)
      end

      assert_receive {:span, span(name: "parent")}
      refute_receive {:span, span(name: "child1")}
      refute_receive {:span, span(name: "child2")}
      refute_receive {:span, span(name: "child3")}
      refute_receive {:span, span(name: "child4")}
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

  def telemetry_console_exporter(_ \\ []) do
    ExUnit.CaptureLog.capture_log(fn -> :application.stop(:opentelemetry) end)

    :application.set_env(:opentelemetry, :tracer, :ot_tracer_default)

    :application.set_env(:opentelemetry, :processors, [
      {:ot_batch_processor, %{scheduled_delay_ms: 1}}
    ])

    :application.start(:opentelemetry)

    :ot_batch_processor.set_exporter(:ot_exporter_stdout, [])

    :ok
  end

  def telemetry_hc_console_exporter(_ \\ []) do
    ExUnit.CaptureLog.capture_log(fn -> :application.stop(:opentelemetry) end)

    :application.set_env(:opentelemetry, :tracer, :ot_tracer_default)

    :application.set_env(:opentelemetry, :processors, [
      {:ot_batch_processor, %{scheduled_delay_ms: 1}}
    ])

    :application.start(:opentelemetry)

    :ot_batch_processor.set_exporter(OpenTelemetry.Honeycomb.Exporter,
      write_key: "HONEYCOMB_KEY",
      http_module: OpenTelemetry.Honeycomb.Http.ConsoleBackend
    )

    :ok
  end

  def make_link(parent_ctx \\ OpenTelemetry.Tracer.current_span_ctx()) do
    trace_id = OpenTelemetry.Span.trace_id(parent_ctx)
    span_id = OpenTelemetry.Span.span_id(parent_ctx)
    tracestate = OpenTelemetry.Span.tracestate(parent_ctx)
    OpenTelemetry.link(trace_id, span_id, [], tracestate)
  end
end
