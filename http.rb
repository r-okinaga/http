require 'net/https'
require 'openssl'
require 'io/console'
require 'csv'
require 'uri'
require 'date'

class ZAC

    EXCLUDE_TYPE = %w(社長 派遣社員 -)
    EXCLUDE_SECTION = %w(いきいきライフ木場店 Nagomi名取店 集計区分)
    EXCLUDE_PROJECTS = '管理用案件'

    def self.open(user_name, password)
        z = ZAC.new
        z.login(user_name, password)

        yield z if block_given?
    ensure
        z.logout
    end

    def login(user_name, password)
        @http = Net::HTTP.new('signovate.jp.oro.com',443)
        @http.use_ssl = true
        @http.verify_mode = OpenSSL::SSL::VERIFY_NONE

        response = @http.post(
            '/signovate/User/user_check.asp',
            encode_params(
                user_name: user_name,
                password: password,
                __page_id: ''
            )
        )

        @cookie =  response.get_fields('set-cookie').join(';')
    end

    def logout
        @http.get(
            '/signovate/Logon/logoff.asp',
            'Cookie' => @cookie
        )
    end

    def choice_output(num, start_date, end_date)
        case num
            when 1
                get_kinmu(start_date, end_date)

            when 2
                get_uriage(start_date, end_date)
        end
    end

    #勤務情報アウトプット
    def get_kinmu(start_date, end_date)
        response = @http.get(
            'https://signovate.jp.oro.com/signovate/Output/CSV/KinmuhyouCSV.asp?%s'%
                encode_params(
                    status: '',
                    type_meisai: 1,
                    y_date_begin: start_date.year,
                    m_date_begin: start_date.month,
                    d_date_begin: start_date.day,
                    y_date_end: end_date.year,
                    m_date_end: end_date.month,
                    d_date_end: end_date.day,
                    id_bumon: '',
                    id_member_yakushoku: '',
                    code_member: '',
                    name_member: '',
                    time_card_in_begin_h: '',
                    time_card_in_begin_m: 0,
                    time_card_in_end_h: '',
                    time_card_in_end_m: 0,
                    time_card_out_begin_h: '',
                    time_card_out_begin_m: 0,
                    time_card_out_end_h: '',
                    time_card_out_end_m: 0,
                    time_in_begin_h: '',
                    time_in_begin_m: 0,
                    time_in_end_h: '',
                    time_in_end_m: 0,
                    time_out_begin_h: '',
                    time_out_begin_m: 0,
                    time_out_end_h: '',
                    time_out_end_m: 0,
                    type_minute_other: 0,
                    minute_other_begin_h: 0,
                    minute_other_begin_m: 0,
                    minute_other_end_h: 0,
                    minute_other_end_m: 0,
                    shukei_unit_1: 0,
                    shukei_unit_2: 0,
                    shukei_unit_3: 0,
                    time_unit: 1,
                    __page_id: ''),
            'Cookie' => @cookie
        )
        data = CSV.parse(response.body.encode('utf-8', 'sjis'))
        kinmu_filter(data)
    end

    def get_uriage(start_date, end_date)
        response = @http.get(
            'https://signovate.jp.oro.com/signovate/Output/CSV/GenkaMeisaiCSV.asp?%s'%
                encode_params(
                    status: 1,
                    hidden_id_bumon: '',
                    id_bumon: '',
                    hidden_id_current_member: 321,
                    y_date_begin: start_date.year,
                    m_date_begin: start_date.month,
                    y_date_end: end_date.year,
                    m_date_end: end_date.month,
                    bumon_all: '',
                    bumon: '',
                    type_uriage: 3,
                    code_shukeikubun: '',
                    name_shukeikubun: '',
                    code_member: '',
                    type_project: 0,
                    type_rieki_idou: 3,
                    type_meisai: 0,
                    code_project_group: '',
                    name_project_group: '',
                    sum_1: 0,
                    sum_2: 0,
                    sum_3: 0,
                    sum_4: 0,
                    sum_5: 0,
                    sum_6: 0,
                    show_actual_cost: 0,
                    is_bumon_latest: 1,
                    __page_id: ''),
            'Cookie' => @cookie
        )
        data = CSV.parse(response.body.encode('utf-8', 'sjis'))
        uriage_filter(data)
    end

    private
    def encode_params(params)
        params.map do |key, value|
            [key.to_s, URI.encode_www_form_component(value)].join('=')
        end.join('&')
    end

    def uriage_filter(data)
        data.delete_if do |line|
            line[2].include? EXCLUDE_PROJECTS
        end.map do |line|
            [line[8], line[102], line[104]]
        end.group_by do |section, uriage, arari|
            section
        end.map do |key, value|
            uriage = arari = 0
            value.each_index do |v|
                uriage += value[v][1].to_i
                arari += value[v][2].to_i
            end
            [key, uriage, arari]
        end.delete_if do |section, uriage, arari|
            EXCLUDE_SECTION.include? section
        end
    end

    def kinmu_filter(data)
        data.delete_if do |line|
            EXCLUDE_TYPE.include? line[5]
        end.delete_if do |line|
            EXCLUDE_SECTION.include? line[9]
        end.map do |line|
            [line[4], line[11]]
        end.select do |name, presence|
            presence.nil?
        end.group_by do |name, presence|
            name
        end.map do |name, list|
            [name, list.length]
        end.sort do |a, b|
            a[1] <=> b[1]
        end
    end


end

print "ユーザー名を入力してください\n"
user_name = gets.to_s.chomp
print "パスワードを入力してください\n"
password = STDIN.noecho(&:gets).chomp
print "アウトプットを番号で選んでください\n"
puts "1 日報未確定日数"
puts "2 当月売上・粗利"
num = gets.to_i

#本来は入力させる
start_date = Date.parse('2016/6/1')
end_date = Date.parse('2016/6/30')

ZAC.open(user_name, password) do |z|
    print "\n実行中\n\n"

    data = z.choice_output(num, start_date, end_date)

    case num
        when 1
            puts data.map {|name, days|
                "#{name}: #{days}日"
            }.join("\n")
        when 2
            puts data.map {|section, uriage, arari|
                "#{section}: 売上:#{uriage}円  粗利:#{arari}円"
            }
    end
end