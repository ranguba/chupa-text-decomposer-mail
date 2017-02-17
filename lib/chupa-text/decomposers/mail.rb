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
        mail.body.parts.each_with_index do |part, i|
          body = part.body.decoded
          body.force_encoding(part.charset)

          part_data = TextData.new(body)
          part_data.uri = "#{data.uri}\##{i}"
          part_data.mime_type = part.mime_type
          data.attributes.each do |name, value|
            part_data[name] = value
          end
          part_data[:encoding] = body.encoding.to_s
          part_data[:subject] = mail.subject
          part_data[:author] = mail[:from].formatted | mail[:from].addresses
          yield(part_data)
        end
      end
    end
  end
end
