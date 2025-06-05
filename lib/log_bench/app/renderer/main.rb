# frozen_string_literal: true

module LogBench
  module App
    module Renderer
      class Main
        def initialize(screen, state)
          self.screen = screen
          self.state = state
          self.scrollbar = Scrollbar.new(screen)
          self.ansi_renderer = Ansi.new(screen)
          self.header = Header.new(screen, state)
          self.request_list = RequestList.new(screen, state, scrollbar)
          self.details = Details.new(screen, state, scrollbar, ansi_renderer)
        end

        def draw
          header.draw
          request_list.draw
          details.draw
          screen.refresh_all
        end

        private

        attr_accessor :screen, :state, :header, :scrollbar, :request_list, :ansi_renderer, :details
      end
    end
  end
end
