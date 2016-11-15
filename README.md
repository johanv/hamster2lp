# hamster2lp

This hack fills out LiquidPlanner timesheets based on information from the
project hamster database.

It does not pull tasks from LiquidPlanner, it works the other way round. It
creates tasks in LiquidPlanner if hamster tasks aren't found. This is because
I don't use LiquidPlanner for planning, I only use it for time tracking.

## how it works

Create a file `~/.h2lprc`, based on the contents of [h2lprc.example](h2lprc.example). 
You need to provide your LiquidPlanner credentials, and mappings from
hamster categories to LiquidPlanner folders. You can also map all tasks
of a hamster category to one particular LiquidPlanner task.

Hamster tasks in projects without mapping are ignored.

The script does some kind of logging in a file `~/.h2lp.facts` to prevent
times to be logged twice.

## but why?

I recently discovered [taskwarrior](https://taskwarrior.org/), which quickly
became my favourite task manager. It can import issues from Redmine
(see [bugwarrior](https://github.com/ralphbean/bugwarrior)) and it also
integrates with [project hamster](https://github.com/projecthamster/hamster-gtk),
(see [taskwarrior-hamster-hook](https://github.com/fmeynadier/taskwarrior-hamster-hook)),
a time tracker I have been using for several years.

Now my collegues use LiquidPlanner for planning and time tracking, and I have to
enter my time tracking in LiquidPlanner as well. I have been doing this way too often,
so now at last I have a script to do this.

## don't try this at home

This is a hack. If you want to use it, you can, but don't recommend this to
others. It might ruin your LiquidPlanner. You can do script injection via task
names, and other horrible stuff. I just created this to avoid boring work.

