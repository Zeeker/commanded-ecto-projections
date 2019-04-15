defmodule Commanded.Projections.AfterUpdateCallbackTest do
  use ExUnit.Case
  doctest Commanded.Projections.Ecto

  alias Commanded.Projections.Repo

  defmodule AnEvent do
    defstruct name: "AnEvent", pid: nil
  end

  defmodule NoopEvent do
    defstruct pid: nil
  end

  defmodule Projection do
    use Ecto.Schema

    schema "projections" do
      field(:name, :string)
    end
  end

  defmodule Projector do
    use Commanded.Projections.Ecto, name: "projection"

    project %AnEvent{name: name}, fn multi ->
      Ecto.Multi.insert(multi, :my_projection, %Projection{name: name})
    end

    project %NoopEvent{}, fn multi ->
      multi
    end

    def after_update(event, metadata, changes) do
      send(event.pid, {event, metadata, changes})
      :ok
    end
  end

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  test "should call `after_update` function with event, metadata and changes" do
    event = %AnEvent{pid: self()}
    metadata = %{event_number: 1}

    assert :ok == Projector.handle(event, metadata)

    assert_receive {^event, ^metadata, changes}

    case Map.get(changes, :my_projection) do
      %Projection{name: "AnEvent"} -> :ok
      _ -> flunk("invalid changes")
    end
  end

  test "should call `after_update` function with event, metadata and an empty map as changes" do
    event = %NoopEvent{pid: self()}
    metadata = %{event_number: 1}
    changes = %{}

    assert :ok == Projector.handle(event, metadata)

    assert_receive {^event, ^metadata, ^changes}
  end
end
