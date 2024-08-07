defmodule Plausible.Stats.TimeTest do
  use Plausible.DataCase, async: true

  import Plausible.Stats.Time

  describe "time_labels/1" do
    test "with time:month dimension" do
      assert time_labels(%{
               dimensions: ["visit:device", "time:month"],
               date_range: Date.range(~D[2022-01-17], ~D[2022-02-01])
             }) == [
               "2022-01-01",
               "2022-02-01"
             ]

      assert time_labels(%{
               dimensions: ["visit:device", "time:month"],
               date_range: Date.range(~D[2022-01-01], ~D[2022-03-07])
             }) == [
               "2022-01-01",
               "2022-02-01",
               "2022-03-01"
             ]
    end

    test "with time:week dimension" do
      assert time_labels(%{
               dimensions: ["time:week"],
               date_range: Date.range(~D[2020-12-20], ~D[2021-01-08])
             }) == [
               "2020-12-20",
               "2020-12-21",
               "2020-12-28",
               "2021-01-04"
             ]

      assert time_labels(%{
               dimensions: ["time:week"],
               date_range: Date.range(~D[2020-12-21], ~D[2021-01-03])
             }) == [
               "2020-12-21",
               "2020-12-28"
             ]
    end

    test "with time:day dimension" do
      assert time_labels(%{
               dimensions: ["time:day"],
               date_range: Date.range(~D[2022-01-17], ~D[2022-02-02])
             }) == [
               "2022-01-17",
               "2022-01-18",
               "2022-01-19",
               "2022-01-20",
               "2022-01-21",
               "2022-01-22",
               "2022-01-23",
               "2022-01-24",
               "2022-01-25",
               "2022-01-26",
               "2022-01-27",
               "2022-01-28",
               "2022-01-29",
               "2022-01-30",
               "2022-01-31",
               "2022-02-01",
               "2022-02-02"
             ]
    end

    test "with time:hour dimension" do
      assert time_labels(%{
               dimensions: ["time:hour"],
               date_range: Date.range(~D[2022-01-17], ~D[2022-01-17])
             }) == [
               "2022-01-17 00:00:00",
               "2022-01-17 01:00:00",
               "2022-01-17 02:00:00",
               "2022-01-17 03:00:00",
               "2022-01-17 04:00:00",
               "2022-01-17 05:00:00",
               "2022-01-17 06:00:00",
               "2022-01-17 07:00:00",
               "2022-01-17 08:00:00",
               "2022-01-17 09:00:00",
               "2022-01-17 10:00:00",
               "2022-01-17 11:00:00",
               "2022-01-17 12:00:00",
               "2022-01-17 13:00:00",
               "2022-01-17 14:00:00",
               "2022-01-17 15:00:00",
               "2022-01-17 16:00:00",
               "2022-01-17 17:00:00",
               "2022-01-17 18:00:00",
               "2022-01-17 19:00:00",
               "2022-01-17 20:00:00",
               "2022-01-17 21:00:00",
               "2022-01-17 22:00:00",
               "2022-01-17 23:00:00"
             ]

      assert time_labels(%{
               dimensions: ["time:hour"],
               date_range: Date.range(~D[2022-01-17], ~D[2022-01-18])
             }) == [
               "2022-01-17 00:00:00",
               "2022-01-17 01:00:00",
               "2022-01-17 02:00:00",
               "2022-01-17 03:00:00",
               "2022-01-17 04:00:00",
               "2022-01-17 05:00:00",
               "2022-01-17 06:00:00",
               "2022-01-17 07:00:00",
               "2022-01-17 08:00:00",
               "2022-01-17 09:00:00",
               "2022-01-17 10:00:00",
               "2022-01-17 11:00:00",
               "2022-01-17 12:00:00",
               "2022-01-17 13:00:00",
               "2022-01-17 14:00:00",
               "2022-01-17 15:00:00",
               "2022-01-17 16:00:00",
               "2022-01-17 17:00:00",
               "2022-01-17 18:00:00",
               "2022-01-17 19:00:00",
               "2022-01-17 20:00:00",
               "2022-01-17 21:00:00",
               "2022-01-17 22:00:00",
               "2022-01-17 23:00:00",
               "2022-01-18 00:00:00",
               "2022-01-18 01:00:00",
               "2022-01-18 02:00:00",
               "2022-01-18 03:00:00",
               "2022-01-18 04:00:00",
               "2022-01-18 05:00:00",
               "2022-01-18 06:00:00",
               "2022-01-18 07:00:00",
               "2022-01-18 08:00:00",
               "2022-01-18 09:00:00",
               "2022-01-18 10:00:00",
               "2022-01-18 11:00:00",
               "2022-01-18 12:00:00",
               "2022-01-18 13:00:00",
               "2022-01-18 14:00:00",
               "2022-01-18 15:00:00",
               "2022-01-18 16:00:00",
               "2022-01-18 17:00:00",
               "2022-01-18 18:00:00",
               "2022-01-18 19:00:00",
               "2022-01-18 20:00:00",
               "2022-01-18 21:00:00",
               "2022-01-18 22:00:00",
               "2022-01-18 23:00:00"
             ]
    end
  end
end
