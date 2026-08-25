module Indicators
  include Namo::Formulary

  def signed_volume(row)
    row[:buys] - row[:sells]
  end

  def cum_delta(row, namo)
    namo[date: ..row[:date]].values(:signed_volume).sum
  end
end
