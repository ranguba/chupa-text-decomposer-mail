# Copyright (C) 2017-2020  Sutou Kouhei <kou@clear-code.com>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

require "pathname"

class TestMail < Test::Unit::TestCase
  include Helper

  def setup
    @options = {}
  end

  private
  def decomposer
    ChupaText::Decomposers::Mail.new(@options)
  end

  sub_test_case("target?") do
    sub_test_case("extension") do
      def create_data(uri)
        data = ChupaText::Data.new
        data.body = ""
        data.uri = uri
        data
      end

      def test_eml
        assert do
          decomposer.target?(create_data("0.eml"))
        end
      end

      def test_mew
        assert do
          decomposer.target?(create_data("0.mew"))
        end
      end

      def test_txt
        assert do
          not decomposer.target?(create_data("0.txt"))
        end
      end
    end

    sub_test_case("mime-type") do
      def create_data(mime_type)
        data = ChupaText::Data.new
        data.mime_type = mime_type
        data
      end

      def test_rfc822
        assert do
          decomposer.target?(create_data("message/rfc822"))
        end
      end

      def test_html
        assert do
          not decomposer.target?(create_data("text/html"))
        end
      end
    end
  end

  sub_test_case("decompose") do
    private
    def decompose(path)
      data = ChupaText::InputData.new(path)
      data.mime_type = "message/rfc822"

      decomposed = []
      decompose_data(data) do |decomposed_data|
        decomposed << decomposed_data
      end
      decomposed
    end

    def decompose_data(data, &block)
      decomposer.decompose(data) do |decomposed_data|
        if decomposer.target?(decomposed_data)
          decompose_data(decomposed_data, &block)
        else
          yield(decomposed_data)
        end
      end
    end

    sub_test_case("attributes") do
      def test_subject
        assert_equal(["Hello"], decompose("subject"))
      end

      def test_from
        assert_equal([["Sender <from@example.com>", "from@example.com"]],
                     decompose("from"))
      end

      def test_to
        assert_equal([
                       [
                         "Recipient1 <to1@example.com>",
                         "Recipient2 <to2@example.com>",
                         "to1@example.com",
                         "to2@example.com",
                       ]
                     ],
                     decompose("to"))
      end

      def test_date
        assert_equal([DateTime.parse("2017-02-19T00:27:55+09:00")],
                     decompose("date"))
      end

      def test_message_id
        assert_equal(["20170219.002755.448326596437930905@example.com"],
                     decompose("message-id"))
      end

      private
      def decompose(attribute_name)
        super(fixture_path("attributes.eml")).collect do |data|
          data[attribute_name]
        end
      end
    end

    sub_test_case("one page") do
      def test_body
        assert_equal(["World\r\n"], decompose.collect(&:body))
      end

      private
      def decompose
        super(fixture_path("text.eml"))
      end
    end

    sub_test_case("multipart") do
      def test_body
        assert_equal(["World", "<p>World</p>"],
                     decompose.collect(&:body))
      end

      private
      def decompose
        super(fixture_path("multipart.eml"))
      end
    end

    sub_test_case("no MIME") do
      def test_body
        assert_equal(["World\n"], decompose.collect(&:body))
      end

      private
      def decompose
        super(fixture_path("no-mime.eml"))
      end
    end

    sub_test_case("nested message/rfc822") do
      def test_body
        assert_equal([
                       [
                         fixture_path("nested-rfc822.eml") + "#0-0-0",
                         "Sub World",
                       ],
                     ],
                     decompose.collect {|data| [data.uri.to_s, data.body]})
      end

      private
      def decompose
        super(fixture_path("nested-rfc822.eml"))
      end
    end

    sub_test_case("unknown encoding") do
      def test_body
        assert_raise(ChupaText::UnknownEncodingError) do
          decompose
        end
      end

      private
      def decompose
        super(fixture_path("unknown-encoding.eml"))
      end
    end
  end
end
