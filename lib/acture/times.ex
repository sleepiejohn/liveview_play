defmodule Acture.DateTimeFormat do
  @relative Timex.Format.DateTime.Formatters.Relative

  def relative(time, timezone \\ nil)

  def relative(time, timezone) when is_nil(timezone),
    do: Timex.format!(time, "{relative}", @relative)

  def relative(time, timezone), do: Timex.Timezone.convert(time, timezone) |> relative(nil)
end
