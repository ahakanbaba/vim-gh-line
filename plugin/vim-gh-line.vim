"% Preliminary validation of global variables
"  and version of the editor.

if v:version < 700
  finish
endif

" check whether this script is already loaded
if exists('g:loaded_gh_line')
  finish
endif

let g:loaded_gh_line = 1

if !exists('g:gh_line_map_default')
    let g:gh_line_map_default = 1
endif

if !exists('g:gh_trace')
    let g:gh_trace = 0
endif

if !exists('g:gh_line_blame_map_default')
    let g:gh_line_blame_map_default = 1
endif

if !exists('g:gh_open_command')
    let g:gh_open_command = 'open '
endif

if !exists('g:gh_line_map') && g:gh_line_map_default == 1
    let g:gh_line_map = '<leader>gh'
endif

if !exists('g:gh_line_blame_map') && g:gh_line_blame_map_default == 1
    let g:gh_line_blame_map = '<leader>gb'
endif

if !exists('g:gh_use_canonical')
    let g:gh_use_canonical = 1
endif

if !exists('g:gh_gitlab_only_http')
    let g:gh_gitlab_only_http = 0
endif

func! s:gh_line(action) range
    " Get Line Number/s
    let lineNum = line('.')
    let fileName = resolve(expand('%:t'))
    let fileDir = resolve(expand("%:p:h"))
    let cdDir = "cd '" . fileDir . "'; "

    " If the remote is using ssh protocol, we need to turn a git remote like this:
    " `git@github.com:user/repo.git`
    " To a url like this:
    " `https://github.com/user/repo`
    "
    " If the remote is using https protocol we only need to get rid of the
    " trailing `.git`. Turn a git remote like this:
    " `https://github.com/user/repo.git`
    " To a url like this:
    " `https://github.com/user/repo`
    "
    " So we do the following replacements:
    " 1. `<userName>@<url>:<user>/<repo>` becomes
    "    https://<url>/<user>/<repo>. Only applicable for remotes using ssh
    "    protocol.
    " 2. Strip the `.git` part in the end.
    let sed_cmd = "sed 's\/^[^@:]*@\\([^:]*\\):\/https:\\\/\\\/\\1\\\/\/; s\/.git$\/\/; '"
    let origin = system(cdDir . "git config --get remote.origin.url" . " | " . sed_cmd)

    " Get Directory & File Names
    let fullPath = resolve(expand("%:p"))
    " Git Commands
    let commit = s:Commit(cdDir)
    let gitRoot = system(cdDir . "git rev-parse --show-toplevel")

    " Strip Newlines
    let origin = <SID>StripNL(origin)
    let commit = <SID>StripNL(commit)
    let gitRoot = <SID>StripNL(gitRoot)
    let fullPath = <SID>StripNL(fullPath)
    let action = s:Action(origin, a:action)

    " Git Relative Path
    let relative = split(fullPath, gitRoot)[-1]

    " Set Line Number/s; Form URL With Line Range
    if s:Github(origin)
      let lineRange = s:GithubLineLange(a:firstline, a:lastline, lineNum)
      let url = origin . action . commit . relative . '#' . lineRange
    elseif s:Bitbucket(origin)
      let lineRange = s:BitbucketLineRange(a:firstline, a:lastline, lineNum)
      let url = s:BitBucketUrl(origin) . action . commit . relative . '#' . lineRange
    elseif s:Gitlab(origin)
      let lineRange = s:GitLabLineRange(a:firstline, a:lastline, lineNum)
      let url = s:GitLabUrl(origin) . action . commit . relative . '#' . lineRange
    endif

    let l:finalCmd = g:gh_open_command . url
    if g:gh_trace
        echom "vim-gh-line executing: " . l:finalCmd
    endif
    call system(l:finalCmd)
endfun

func! s:Action(origin, action)
  if a:action == 'blame'
    if s:Bitbucket(a:origin)
      return '/annotate/'
    else
      return '/blame/'
    endif
  elseif a:action == 'blob'
    if s:Bitbucket(a:origin)
      return '/src/'
    else
      return '/blob/'
    endif
  endif
endfunc

func! s:Commit(cdDir)
  if exists('g:gh_use_canonical')
    return system(a:cdDir . 'git rev-parse HEAD')
  else
    return system(a:cdDir . 'git rev-parse --abbrev-ref HEAD')
  endif
endfunc

func! s:Github(origin)
  return exists('g:gh_github_domain') && match(a:origin, g:gh_github_domain) || match(a:origin, 'github') >= 0
endfunc

func! s:Bitbucket(origin)
  return match(a:origin, 'bitbucket.org') >= 0
endfunc

func! s:Gitlab(origin)
  return exists('g:gh_gitlab_domain') && match(a:origin, g:gh_gitlab_domain) || match(a:origin, 'gitlab') >= 0
endfunc

func! s:GithubLineLange(firstLine, lastLine, lineNum)
  if a:firstLine == a:lastLine
    return 'L' . a:lineNum
  else
    return 'L' . a:firstLine . '-L' . a:lastLine
  endif
endfunc

func! s:BitbucketLineRange(firstLine, lastLine, lineNum)
  if a:firstLine == a:lastLine
    return '-' . a:lineNum
  else
    return '-' . a:firstLine . ':' . a:lastLine
  endif
endfunc

func! s:GitLabLineRange(firstLine, lastLine, lineNum)
  if a:firstLine == a:lastLine
    return 'L' . a:lineNum
  else
    return 'L' . a:firstLine . '-' . a:lastLine
  endif
endfunc

func! s:StripNL(l)
  return substitute(a:l, '\n$', '', '')
endfun

func! s:BitBucketUrl(origin)
  return substitute(a:origin, '\(:\/\/\)\@<=.*@', '', '')
endfunc

func! s:GitLabUrl(origin)
  let l:origin = a:origin
  if g:gh_gitlab_only_http
    let l:origin = substitute(l:origin, 'https://', 'http://', '')
  endif
  return l:origin
endfunc

noremap <silent> <Plug>(gh-line) :call <SID>gh_line('blob')<CR>
noremap <silent> <Plug>(gh-line-blame) :call <SID>gh_line('blame')<CR>

if !hasmapto('<Plug>(gh-line)') && exists('g:gh_line_map')
    exe "map" g:gh_line_map "<Plug>(gh-line)"
end

if !hasmapto('<Plug>(gh-line-blame)') && exists('g:gh_line_blame_map')
    exe "map" g:gh_line_blame_map "<Plug>(gh-line-blame)"
end
