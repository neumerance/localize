desc 'Generate ctags'
task :ctags	do
  %x(ctags -R --exclude=.svn --exclude=log *)
end
