require 'csv'
require 'net/http'
require 'json'
require 'uri'

namespace :univ do
  desc 'Fetch university exam dates using ChatGPT API'
  task fetch: :environment do
    # APIキー（ハードコード）
    api_key = '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'

    # OpenAI APIのエンドポイント
    api_url = 'https://api.openai.com/v1/responses'

    # システムプロンプト（ハードコード）
    system_prompt = 'ユーザーから大学名が指定されます。指定された大学の2026年入試に関する情報を調査し、すべての試験会場（サテライト会場含む）について、以下のJSONフォーマットで正確に出力してください。

出力形式:
- 各試験会場ごとに1つのJSONオブジェクトを作成し、すべてを1つのJSON配列で出力してください。
- 出力はJSONデータのみとし、他の文言は含めないでください。

フォーマット例:
[
  {
    "univ_name": "大学名",
    "test_venue_name": "試験会場名",
    "test_venue_pref": "試験会場の都道府県名",
    "test_venue_address": "試験会場の住所",
    "dates": "2026/2/1,2026/2/2",
    "remarks": "試験名など、備考があれば40文字以内で簡潔に。",
    "source_url": "情報ソースのURL",
    "requirements_url": "要項のURL（情報ソースと別に要項を参照した場合はこちらに出力すること）"
  }
]

補足:
* datesはカンマ区切りの文字列で出力してください。日付が1つの場合は1つの文字列でよいです。日付情報が不明な場合は空文字列（""）にしてください。
* データが見つからない、または曖昧な場合は、そのフィールドを空文字列（""）にしてください。
* JSON配列以外のテキストや説明は一切出力しないでください。
* 確実に2026年度入学の入試日程を検索すること。
* 会場の住所は要項の下部に記載されていることが多いですのでしっかり検索して、正確に出力すること。住所が不明な場合でも都道府県名までは分かる場合は出力すること。
* サテライト会場の検索を忘れないように気をつけてください。

## Output Format
出力はuniv_name, test_venue_name, test_venue_pref, test_venue_address, dates, remarks, source_url, requirements_urlの順のフィールドを持つオブジェクトからなる1つのJSON配列のみとしてください。例:
[
  {
    "univ_name": "○○大学",
    "test_venue_name": "本学キャンパス",
    "test_venue_pref": "東京都",
    "test_venue_address": "東京都○○区○○1-2-3",
    "dates": "2026/2/1,2026/2/2",
    "remarks": "一般選抜入試Ａ日程Ⅰ期",
    "source_url": "https://example.ac.jp/nyushi-venue",
    "requirements_url": "https://example.ac.jp/youkou.pdf"
  },
  {
    "univ_name": "○○大学",
    "test_venue_name": "豊中会場（豊中市公民会館）",
    "test_venue_pref": "大阪府",
    "test_venue_address": "大阪府○○市○○4-5-6",
    "dates": "2026/2/4",
    "remarks": "前期３科目型",
    "source_url": "https://example.ac.jp/nyushi-venue",
    "requirements_url": "https://example.ac.jp/youkou.pdf"
  }
]'

    # univ.csvファイルを読み込む
    csv_path = Rails.root.join('univ.csv')

    unless File.exist?(csv_path)
      puts "Error: univ.csv not found at #{csv_path}"
      exit 1
    end

    # 出力ディレクトリの確保
    output_dir = Rails.root.join('out')
    FileUtils.mkdir_p(output_dir) unless Dir.exist?(output_dir)

    # CSVファイルの各行を処理
    CSV.foreach(csv_path) do |row|
      university_name = row[0].strip
      puts "Processing: #{university_name}"

      # 出力ファイルパスを事前に確認
      output_path = output_dir.join("#{university_name}.txt")

      # ファイルが既に存在する場合はスキップ
      if File.exist?(output_path)
        puts "#{Time.current}  -> Skipped (file already exists): #{output_path}"
        next
      end

      begin
        # リクエストボディの作成
        request_body = {
          model: 'gpt-5',
          tools: [{ type: 'web_search' }],
          input: "#{system_prompt}\n\n大学名: #{university_name}"
        }

        # HTTPリクエストの送信
        uri = URI.parse(api_url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = 600  # 10分
        http.open_timeout = 600  # 10分

        request = Net::HTTP::Post.new(uri.path)
        request['Content-Type'] = 'application/json'
        request['Authorization'] = "Bearer #{api_key}"
        request.body = request_body.to_json

        response = http.request(request)
        response_data = JSON.parse(response.body)

        # レスポンスの確認
        if response.code.to_i != 200
          raise "API Error: #{response_data}"
        end

        # レスポンスからtextフィールドを抽出
        # response_data['output'] の中に配列が含まれている
        output_events = response_data['output']

        if output_events.nil? || !output_events.is_a?(Array)
          raise "Invalid response structure: 'output' field not found or not an array"
        end

        # messageタイプの要素を検索
        message_item = output_events.find { |item| item['type'] == 'message' }

        if message_item.nil?
          raise "No message found in response"
        end

        text_content = message_item.dig('content', 0, 'text')

        if text_content.nil?
          raise "No text content found in message"
        end

        # テキストをJSONとしてパースして、pretty printする
        json_data = JSON.parse(text_content)
        pretty_json = JSON.pretty_generate(json_data)

        # 結果をファイルに出力
        File.write(output_path, pretty_json)

        puts "#{Time.current}  -> Saved to: #{output_path}"

      rescue => e
        puts "  -> Error: #{e.message}"
        # エラーの場合もファイルを作成（エラー内容を記録）
        puts response_data if defined?(response_data)
        error_output = "Error occurred: #{e.message}\n#{e.backtrace.join("\n")}"
        error_output += "\n\n\nResponse Data:\n#{response_data}" if defined?(response_data)
        File.write(output_path, error_output)
      end

      # API rate limitを考慮して少し待機
      sleep 1
    end

    puts "\nAll universities processed!"
  end
end
