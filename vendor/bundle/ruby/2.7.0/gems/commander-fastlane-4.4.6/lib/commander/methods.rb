module Commander
  module Methods
    include Commander::UI
    include Commander::UI::AskForClass
    include Commander::Delegates

    if $stdin.tty? && (cols = $terminal.output_cols) >= 40
      $terminal.wrap_at = cols - 5
    end
  end
end
