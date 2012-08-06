#!/usr/bin/env ruby

require "fileutils"


Dir.chdir

if File.exist?("dotfiles")
  FileUtils.remove_dir('dotfiles')
end

system("git clone git://github.com/takaheraw/dotfiles.git dotfiles")
Dir.chdir("dotfiles")

FileUtils.symlink(File.expand_path(".bashrc"), File.expand_path("~/.bashrc"), {:force => true})
FileUtils.symlink(File.expand_path(".vimrc"), File.expand_path("~/.vimrc"), {:force => true})
FileUtils.symlink(File.expand_path(".vim"), File.expand_path("~/.vim"), {:force => true})
