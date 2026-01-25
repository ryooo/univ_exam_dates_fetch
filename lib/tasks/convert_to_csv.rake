require 'json'
require 'csv'

namespace :univ do
  desc 'Convert JSON files to CSV'
  task convert_to_csv: :environment do
    output_dir = Rails.root.join('out')
    csv_output_path = Rails.root.join('univ_out.csv')

    unless Dir.exist?(output_dir)
      puts "Error: out directory not found at #{output_dir}"
      exit 1
    end

    # すべてのJSONデータを格納する配列
    all_data = []

    # out/以下のすべての.txtファイルを読み込む
    Dir.glob(File.join(output_dir, '*.txt')).sort.each do |file_path|
      puts "Reading: #{File.basename(file_path)}"

      begin
        content = File.read(file_path)
        json_data = JSON.parse(content)

        # 配列でない場合はスキップ
        unless json_data.is_a?(Array)
          puts "  -> Skipped (not a JSON array)"
          next
        end

        # 配列要素を結合
        all_data.concat(json_data)
        puts "  -> Added #{json_data.length} records"

      rescue JSON::ParserError => e
        puts "  -> Skipped (JSON parse error): #{e.message}"
      rescue => e
        puts "  -> Skipped (error): #{e.message}"
      end
    end

    puts "\nTotal records before expansion: #{all_data.length}"

    # dates列をカンマ区切りで分解して、各日付ごとに行を作成
    expanded_data = []

    all_data.each do |record|
      dates_str = record['dates'].to_s.strip

      if dates_str.empty?
        # 日付が空の場合は、dateを空文字列として1行追加
        expanded_data << {
          'date' => '',
          'univ_name' => record['univ_name'],
          'test_venue_name' => record['test_venue_name'],
          'test_venue_pref' => record['test_venue_pref'],
          'test_venue_address' => record['test_venue_address'],
          'remarks' => record['remarks'],
          'source_url' => record['source_url']
        }
      else
        # カンマで分割して各日付ごとに行を作成
        dates = dates_str.split(',').map(&:strip)

        dates.each do |date|
          expanded_data << {
            'date' => date,
            'univ_name' => record['univ_name'],
            'test_venue_name' => record['test_venue_name'],
            'test_venue_pref' => record['test_venue_pref'],
            'test_venue_address' => record['test_venue_address'],
            'remarks' => record['remarks'],
            'source_url' => record['source_url']
          }
        end
      end
    end

    puts "Total records after date expansion: #{expanded_data.length}"

    # CSVに出力（BOM付きUTF-8でExcelの文字化けを防ぐ）
    CSV.open(csv_output_path, 'w', encoding: 'BOM|UTF-8') do |csv|
      # ヘッダー行
      csv << ['date', 'univ_name', 'test_venue_name', 'test_venue_pref', 'test_venue_address', 'remarks', 'source_url']

      # データ行
      expanded_data.each do |record|
        csv << [
          record['date'],
          record['univ_name'],
          record['test_venue_name'],
          record['test_venue_pref'],
          record['test_venue_address'],
          record['remarks'],
          record['source_url']
        ]
      end
    end

    puts "\nCSV file created: #{csv_output_path}"
    puts "Total rows (including header): #{expanded_data.length + 1}"
  end
end
