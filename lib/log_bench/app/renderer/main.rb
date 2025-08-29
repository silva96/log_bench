# frozen_string_literal: true

module LogBench
  module App
    module Renderer
      class Main
        def initialize(screen, state, log_file_name)
          self.screen = screen
          self.state = state
          self.scrollbar = Scrollbar.new(screen)
          self.ansi_renderer = Ansi.new(screen)
          self.header = Header.new(screen, state, log_file_name)
          self.request_list = RequestList.new(screen, state, scrollbar)
          self.details = Details.new(screen, state, scrollbar, ansi_renderer)
          self.update_modal = UpdateModal.new(screen, state)
        end

        def draw
          if update_modal.should_show?
            update_modal.draw
          else
            header.draw
            request_list.draw
            details.draw
            screen.refresh_all
          end
        end

        def handle_modal_input(ch)
          update_modal.handle_input(ch)
        end

        def get_cached_detail_lines(request)
          details.get_cached_detail_lines(request)
        end

        private

        attr_accessor :screen, :state, :header, :scrollbar, :request_list, :ansi_renderer, :details, :update_modal
      end
    end
  end
end
