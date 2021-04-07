require "bundler"
Bundler.setup
Bundler.require

if ARGV.size == 2
  Data_range = Date.parse(ARGV[0])..Date.parse(ARGV[1])
else
  raise("Usage ruby #{$0} <Start-Date> <End-Date>")
end

Time_Format = "%Y-%m-%d"

MyDir = File.expand_path(File.dirname(__FILE__))
Dir.chdir(MyDir)

Data_file_ctime = "12-15"
Data_file_ext = "csv"
Data_file_base = "DIVI-Intensivregister"
Data_dir = "./data"
Graphs_dir = "./graphs"
Report_basepath = File.join(Graphs_dir, "corona_icu_report_DE")

def data_filename(_date)
  day = Date.parse(_date).strftime(Time_Format)
  "#{Data_file_base}_#{day}_#{Data_file_ctime}.#{Data_file_ext}"
end

data = []

Data_range.each do |date|
  day = date.strftime(Time_Format)
  csv = CsvHash.read(File.join(Data_dir, data_filename(day)))
  icu_beds_occupied = csv.sum { |x| x["betten_belegt"].to_i }
  icu_beds_free = csv.sum { |x| x["betten_frei"].to_i }
  icu_occupied_cov19_pcr_positive = csv.sum { |x| x["faelle_covid_aktuell"].to_i }
  icu_cov19sari_ventilated = csv.sum { |x| x["faelle_covid_aktuell_beatmet"].to_i }
  icu_beds_total = icu_beds_occupied + icu_beds_free
  icu_occupied_cov19_pcr_negative = icu_beds_occupied - icu_occupied_cov19_pcr_positive
  data << {
    datum: date.strftime(Time_Format),
    icu_beds_total: icu_beds_total,
    icu_beds_occupied: icu_beds_occupied,
    icu_beds_free: icu_beds_free,
    icu_occupied_cov19_pcr_positive: icu_occupied_cov19_pcr_positive,
    icu_cov19sari_ventilated: icu_cov19sari_ventilated,
    icu_occupied_cov19_pcr_negative: icu_occupied_cov19_pcr_negative,
    anteil_betten_nicht_corona_in_prozent: (icu_occupied_cov19_pcr_negative.to_f/icu_beds_total.to_f*100).round,
    anteil_betten_corona_in_prozent: (icu_occupied_cov19_pcr_positive.to_f/icu_beds_total.to_f*100).round,
    anteil_betten_corona_beatmet_in_prozent: (icu_cov19sari_ventilated.to_f/icu_beds_total.to_f*100).round
  }
rescue Errno::ENOENT # file not found, means no data available for this day
  next
end

Numo.gnuplot do |g|
  set term: "pdf color enhanced font \"arial,40\" linewidth 10 size 118.9cm,84cm"
  set output: "#{Report_basepath}.pdf"
  set xlabel: "date"
  set ylabel: "amount of ICU beds"
  set title: "ICU beds report / Germany"
  set "grid"
  set "xdata time"
  set "xtics timedate"
  set "xtics format \"%d.%m.\""
  set "timefmt \"#{Time_Format}\""
  set "format x \"%d.%m.\"" # \"#{Time_Format}\""
  set "xrange [\"#{Data_range.first.strftime(Time_Format)}\":\"#{Data_range.last.strftime(Time_Format)}\"]"
  set "xtics (#{Data_range.step(7).to_a.map { |d| "\"#{d.strftime(Time_Format)}\"" }.join(', ')})"
  # set "x2tics (#{Data_range.step(7).to_a.map { |d| "\"#{d.strftime(Time_Format)}\"" }.join(', ')})"
  set "ytics 1000"
  set "y2tics 1000"
  set "autoscale"
  plot [data.map { |d| d[:datum] }, data.map { |d| d[:icu_beds_total] }, using: "1:2", with: "lines", title: "ICU beds total"],
       [data.map { |d| d[:datum] }, data.map { |d| d[:icu_beds_occupied] }, using: "1:2", with: "lines", title: "ICU beds occupied"],
       [data.map { |d| d[:datum] }, data.map { |d| d[:icu_beds_free] }, using: "1:2", with: "lines", title: "ICU beds free"],
       [data.map { |d| d[:datum] }, data.map { |d| d[:icu_occupied_cov19_pcr_negative] }, using: "1:2", with: "lines", title: "ICU beds Cov-19 PCR negative"],
       [data.map { |d| d[:datum] }, data.map { |d| d[:icu_occupied_cov19_pcr_positive] }, using: "1:2", with: "lines", title: "ICU beds Cov-19 PCR positive"],
       [data.map { |d| d[:datum] }, data.map { |d| d[:icu_cov19sari_ventilated] }, using: "1:2", with: "lines", title: "ICU beds with ventilated Cov-19 SARI cases"]
  
  # jpeg
  begin
    set term: "jpeg font \"arial,12\" linewidth 2 size 2400,1200"
    set output: "#{Report_basepath}.jpg"
    replot
  rescue Numo::GnuplotError
    # for some reason JPEG output creates a GnuPlot error using the same data as PDF (which doesn't throw an exception)
    # but the output is generated anyway 🤷‍♂️
  end

  # SVG
  begin
    set term: "svg font \"arial,12\" linewidth 2 size 2400,1200"
    set output: "#{Report_basepath}.svg"
    replot
  rescue Numo::GnuplotError
    # for some reason SVG output creates a GnuPlot error using the same data as PDF (which doesn't throw an exception)
    # but the output is generated anyway 🤷‍♂️
  end
end

# binding.pry
