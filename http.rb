require 'net/https'
require 'openssl'
require 'io/console'
require 'csv'


module ZAC
    extend self

    EXCLUDE_TYPE = %w(社長 派遣社員 -)
    EXCLUDE_SECTION = %w(いきいきライフ木場店 Nagomi名取店)

    def login
        @http = Net::HTTP.new('signovate.jp.oro.com',443)
        @http.use_ssl = true
        @http.verify_mode = OpenSSL::SSL::VERIFY_NONE

        print "ユーザー名を入力してください\n"
        user_name = gets.to_s
        print "パスワードを入力してください\n"
        password = STDIN.noecho(&:gets)

        response = @http.post('/signovate/User/user_check.asp',"user_name=#{user_name}&password=#{password}&__page_id=")

        @cookie =  response.get_fields('set-cookie').join(';')
    end

    def logout
        @http.get('/signovate/Logon/logoff.asp', 'Cookie' => @cookie)
    end

    #勤務表アウトプット
    def getKinmu
        response = @http.get("https://signovate.jp.oro.com/signovate/Output/CSV/KinmuhyouCSV.asp?status=&type_meisai=1&y_date_begin=2016&m_date_begin=6&d_date_begin=1&y_date_end=2016&m_date_end=6&d_date_end=30&id_bumon=&id_member_yakushoku=&code_member=&name_member=&time_card_in_begin_h=&time_card_in_begin_m=0&time_card_in_end_h=&time_card_in_end_m=0&time_card_out_begin_h=&time_card_out_begin_m=0&time_card_out_end_h=&time_card_out_end_m=0&time_in_begin_h=&time_in_begin_m=0&time_in_end_h=&time_in_end_m=0&time_out_begin_h=&time_out_begin_m=0&time_out_end_h=&time_out_end_m=0&type_minute_other=0&minute_other_begin_h=0&minute_other_begin_m=0&minute_other_end_h=0&minute_other_end_m=0&shukei_unit_1=0&shukei_unit_2=0&shukei_unit_3=0&time_unit=1&__page_id=", 'Cookie' => @cookie)
        data = CSV.parse(response.body.encode('utf-8', 'sjis'))
        filter(data)
    end

    def filter(data)
        output = data.delete_if do |line|

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

        end.map do |name, days|

            "#{name}: #{days}日\n"

        end.join

        puts output

    end
end


begin
    ZAC.login
    ZAC.getKinmu
rescue
    p "エラー"
    ZAC.logout
end

ZAC.logout
