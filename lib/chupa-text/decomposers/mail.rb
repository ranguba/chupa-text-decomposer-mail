# Copyright (C) 2017  Kouhei Sutou <kou@clear-code.com>
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

require "time"

require "mail"

module ChupaText
  module Decomposers
    class Mail < Decomposer
      registry.register("mail", self)

      TARGET_EXTENSIONS = ["eml", "mew"]
      TARGET_MIME_TYPES = ["message/rfc822"]
      def target?(data)
        return true if TARGET_MIME_TYPES.include?(data.mime_type)
        return false unless TARGET_EXTENSIONS.include?(data.extension)

        data.uri.fragment.nil?
      end

      def decompose(data)
        mail = ::Mail.new(data.body)
        decompose_attributes(mail, data)

        if mail.multipart?
          parts = mail.body.parts
        else
          parts = [mail]
        end
        parts.each_with_index do |part, i|
          body = part.body.decoded
          body.force_encoding(part.charset) if part.charset

          part_data = TextData.new(body, :source_data => data)
          part_data.uri = "#{data.uri}\##{i}"
          part_data.mime_type = part.mime_type if part.mime_type
          part_data[:encoding] = body.encoding.to_s
          yield(part_data)
        end
      end

      private
      def decompose_attributes(mail, data)
        data["message-id"] = mail.message_id
        data["subject"] = mail.subject
        data["date"] = mail.date

        from = mail[:from]
        if from
          data["from"] = from.formatted | from.addresses
        end

        to = mail[:to]
        if to
          data["to"] = to.formatted | to.addresses
        end
      end
    end
  end
end
