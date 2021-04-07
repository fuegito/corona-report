require "bundler"
Bundler.setup
Bundler.require

MyDir = File.expand_path(File.dirname(__FILE__))
Dir.chdir(MyDir)

Divi_base_url = "https://www.divi.de/"
Divi_csv_path = "joomlatools-files/docman-files/divi-intensivregister-tagesreports-csv/"
Divi_filename_prefix = "DIVI-Intensivregister_"
Divi_filename_suffix = "_12-15.csv"
Destination_dir = "./data"

faraday_options = {
   ssl: { verify: false },
   proxy: ENV['HTTP_PROXY']
}
Conn = Faraday.new(Divi_base_url, faraday_options)


def get_csv_file(day)
  filename = Divi_filename_prefix + day + Divi_filename_suffix
  path = File.join(Divi_base_url, Divi_csv_path, filename)
  puts "HTTP get: #{path}"
  response = Conn.get(path)
  if response.success?
    File.write(File.join(Destination_dir, filename), response.body)
  else
    # raise("download error: #{response.body}")
    STDERR.puts "download error: #{path}; Response Status Code: #{response.status}"
  end
end


if ARGV.size == 2
  from = Date.parse(ARGV[0])
  to = Date.parse(ARGV[1])
  raise("Usage: #{__FILE__} <from> <to>") if from > to
  (from..to).each do |d|
    day = d.strftime("%Y-%m-%d")
    get_csv_file(day)
  end
elsif ARGV.size == 1
  day = Date.parse(ARGV[0]).strftime("%Y-%m-%d")
  get_csv_file(day)
else
  day = Date.today.strftime("%Y-%m-%d")
  get_csv_file(day)
end

