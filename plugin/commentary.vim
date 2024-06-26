" commentary.vim - Comment stuff out
" Maintainer:   Tim Pope <http://tpo.pe/>
" Version:      1.3
" GetLatestVimScripts: 3695 1 :AutoInstall: commentary.vim

if exists("g:loaded_commentary") || v:version < 704
  finish
endif
let g:loaded_commentary = 1

function! s:surroundings() abort
  return split(get(b:, 'commentary_format', substitute(substitute(substitute(
        \ has('nvim-0.10') ? luaeval('require"commentary".get_commentstring()') : &commentstring,
        \ '^$', '%s', ''), '\S\zs%s',' %s', '') ,'%s\ze\S', '%s ', '')),
        \ '%s', 1)
endfunction

" l_go: Used for (un)commenting. Doesn't get stripped by empty comment.
" l: Used for checking comment range. Stripped by empty comment.
function! s:strip_white_space(l,l_go,r,line) abort
  let [l, l_go, r] = [a:l, a:l_go, a:r]
  if l_go[-1:] ==# ' ' && stridx(a:line,l_go) == -1 && stridx(a:line,l_go[0:-2]) == 0
    if l[-1:]    ==# ' '    | let l    = l[:-2]    | endif
    if l_go[:-2] !=# a:line | let l_go = l_go[:-2] | endif
  endif
  if r[0] ==# ' ' && (' ' . a:line)[-strlen(r)-1:] != r && a:line[-strlen(r):] == r[1:]
    let r = r[1:]
  endif
  return [l, l_go, r]
endfunction

function! s:go(...) abort
  if !a:0
    let &operatorfunc = matchstr(expand('<sfile>'), '[^. ]*$')
    return 'g@'
  elseif a:0 > 1
    let [lnum1, lnum2] = [a:1, a:2]
  else
    let [lnum1, lnum2] = [line("'["), line("']")]
  endif

  let [l, r] = s:surroundings()
  let l_go = l
  let uncomment = 2
  let force_uncomment = a:0 > 2 && a:3
  for lnum in range(lnum1,lnum2)
    let line = matchstr(getline(lnum),'\S.*\s\@<!')
    let [l, l_go, r] = s:strip_white_space(l,l_go,r,line)
    if len(line) && (stridx(line,l) || line[strlen(line)-strlen(r) : -1] != r)
      let uncomment = 0
    endif
  endfor

  if get(b:, 'commentary_startofline')
    let indent = '^'
  else
    let indent = '^\s*'
  endif

  let lines = []
  for lnum in range(lnum1,lnum2)
    let line = getline(lnum)
    if strlen(r) > 2 && l.r !~# '\\' && r !~# '\V*)\|-}\||#' && !force_uncomment
      let line = substitute(line,
            \'\M' . substitute(l, '\ze\S\s*$', '\\zs\\d\\*\\ze', '') . '\|' . substitute(r, '\S\zs', '\\zs\\d\\*\\ze', ''),
            \'\=substitute(submatch(0)+1-uncomment,"^0$\\|^-\\d*$","","")','g')
    endif
    if force_uncomment
      if line =~ '\v\C^\s*' . escape(l, '!#$%&()*+,-./:;<=>?@[\]^{|}~')
        let line = substitute(line,'\S.*\s\@<!','\=submatch(0)[strlen(l_go):-strlen(r)-1]','')
        if line =~# '^\s\+$' | let line = '' | endif
      endif
    elseif uncomment
      let line = substitute(line,'\S.*\s\@<!','\=submatch(0)[strlen(l_go):-strlen(r)-1]','')
      if line =~# '^\s\+$' | let line = '' | endif
    else
      let line = substitute(line,'^\%('.matchstr(getline(lnum1),indent).'\|\s*\)\zs.*\S\@<=','\=l_go.submatch(0).r','')
    endif
    call add(lines, line)
  endfor
  call setline(lnum1, lines)
  silent doautocmd <nomodeline> User CommentaryPost
  return ''
endfunction

function! s:textobject(inner) abort
  let [l, r] = s:surroundings()
  let lnums = [line('.')+1, line('.')-2]
  for [index, dir, bound, line] in [[0, -1, 1, ''], [1, 1, line('$'), '']]
    while lnums[index] != bound && line ==# '' || !(stridx(line,l) || line[strlen(line)-strlen(r) : -1] != r)
      let lnums[index] += dir
      let line = matchstr(getline(lnums[index]+dir),'\S.*\s\@<!')
      let [l, _, r] = s:strip_white_space(l,l,r,line)
    endwhile
  endfor
  while (a:inner || lnums[1] != line('$')) && empty(getline(lnums[0]))
    let lnums[0] += 1
  endwhile
  while a:inner && empty(getline(lnums[1]))
    let lnums[1] -= 1
  endwhile
  if lnums[0] <= lnums[1]
    execute 'normal! 'lnums[0].'GV'.lnums[1].'G'
  endif
endfunction

function! s:insert()
  let [l, r] = s:surroundings()
  return l . r . repeat("\<C-G>U\<Left>", strchars(r))
endfunction

command! -range -bar -bang Commentary call s:go(<line1>,<line2>,<bang>0)
xnoremap <expr>   <Plug>Commentary     <SID>go()
nnoremap <expr>   <Plug>Commentary     <SID>go()
nnoremap <expr>   <Plug>CommentaryLine <SID>go() . '_'
onoremap <silent> <Plug>Commentary        :<C-U>call <SID>textobject(get(v:, 'operator', '') ==# 'c')<CR>
nnoremap <silent> <Plug>ChangeCommentary c:<C-U>call <SID>textobject(1)<CR>
inoremap <expr>   <Plug>CommentaryInsert <SID>insert()

if !hasmapto('<Plug>Commentary') || maparg('gc','n') ==# ''
  xmap gc  <Plug>Commentary
  nmap gc  <Plug>Commentary
  omap gc  <Plug>Commentary
  nmap gcc <Plug>CommentaryLine
  nmap gcu <Plug>Commentary<Plug>Commentary
endif

nmap <silent> <Plug>CommentaryUndo :echoerr "Change your <Plug>CommentaryUndo map to <Plug>Commentary<Plug>Commentary"<CR>

" vim:set et sw=2:
