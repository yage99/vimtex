" vimtex - LaTeX plugin for Vim
"
" Maintainer: Karl Yngve Lervåg
" Email:      karl.yngve@gmail.com
"

function! vimtex#toc#init_buffer() abort " {{{1
  if !g:vimtex_toc_enabled | return | endif

  command! -buffer VimtexTocOpen   call b:vimtex.toc.open()
  command! -buffer VimtexTocToggle call b:vimtex.toc.toggle()

  nnoremap <buffer> <plug>(vimtex-toc-open)   :call b:vimtex.toc.open()<cr>
  nnoremap <buffer> <plug>(vimtex-toc-toggle) :call b:vimtex.toc.toggle()<cr>
endfunction

" }}}1
function! vimtex#toc#init_state(state) abort " {{{1
  if !g:vimtex_toc_enabled | return | endif

  let a:state.toc = deepcopy(s:toc)
endfunction

" }}}1

function! vimtex#toc#get_entries() abort " {{{1
  if !has_key(b:vimtex, 'toc') | return [] | endif

  return b:vimtex.toc.get_entries(0)
endfunction

" }}}1
function! vimtex#toc#refresh() abort " {{{1
  if has_key(b:vimtex, 'toc')
    call b:vimtex.toc.get_entries(1)
  endif
endfunction

" }}}1

let s:toc = {
      \ 'name' : 'Table of contents (vimtex)',
      \ 'types' : g:vimtex_toc_layers,
      \ 'show_help' : g:vimtex_toc_show_help,
      \ 'show_numbers' : g:vimtex_toc_show_numbers,
      \ 'tocdepth' : g:vimtex_toc_tocdepth,
      \ 'hotkeys' : extend({
      \     'enabled' : '0',
      \     'leader' : ';',
      \     'keys' : 'abcdeghijklmnopuvxyz',
      \   }, g:vimtex_toc_hotkeys),
      \ 'todo_sorted' : 1,
      \}

"
" Open and close TOC window
"
function! s:toc.open() abort dict " {{{1
  if self.is_open() | return | endif

  let self.calling_file = expand('%:p')
  let self.calling_line = line('.')

  call self.get_entries(0)

  if g:vimtex_toc_mode > 1
    call setloclist(0, map(deepcopy(self.entries), '{
          \ ''lnum'': v:val.line,
          \ ''filename'': v:val.file,
          \ ''text'': v:val.title,
          \}'))
    try
      call setloclist(0, [], 'r', {'title': self.name})
    catch
    endtry
    if g:vimtex_toc_mode == 4 | lopen | endif
  endif

  if g:vimtex_toc_mode < 3
    call self.create()
  endif
endfunction

" }}}1
function! s:toc.is_open() abort dict " {{{1
  return bufwinnr(bufnr(self.name)) >= 0
endfunction

" }}}1
function! s:toc.toggle() abort dict " {{{1
  if self.is_open()
    call self.close()
  else
    call self.open()
    if has_key(self, 'prev_winid')
      call win_gotoid(self.prev_winid)
    endif
  endif
endfunction

" }}}1
function! s:toc.close() abort dict " {{{1
  let self.fold_level = &l:foldlevel

  if g:vimtex_toc_resize
    silent exe 'set columns -=' . g:vimtex_toc_split_width
  endif

  if g:vimtex_toc_split_pos ==# 'full'
    silent execute 'buffer' self.prev_bufnr
  else
    silent execute 'bwipeout' bufnr(self.name)
  endif
endfunction

" }}}1
function! s:toc.goto() abort dict " {{{1
  if self.is_open()
    let l:prev_winid = win_getid()
    silent execute bufwinnr(bufnr(self.name)) . 'wincmd w'
    let b:toc.prev_winid = l:prev_winid
  endif
endfunction

" }}}1

"
" Get the TOC entries
"
function! s:toc.get_entries(force) abort dict " {{{1
  if has_key(self, 'entries') && !g:vimtex_toc_refresh_always && !a:force
    return self.entries
  endif

  let self.entries = vimtex#parser#toc(b:vimtex.tex)
  let self.topmatters = vimtex#parser#toc#get_topmatters()

  "
  " Sort todo entries
  "
  if self.todo_sorted
    let l:todos = filter(copy(self.entries), 'v:val.type ==# ''todo''')
    for l:t in l:todos[1:]
      let l:t.level = 1
    endfor
    call filter(self.entries, 'v:val.type !=# ''todo''')
    let self.entries = l:todos + self.entries
  endif

  "
  " Add hotkeys to entries
  "
  if self.hotkeys.enabled
    let k = strwidth(self.hotkeys.keys)
    let n = len(self.entries)
    let m = len(s:base(n, k))
    let i = 0
    for entry in self.entries
      let keys = map(s:base(i, k), 'strcharpart(self.hotkeys.keys, v:val, 1)')
      let keys = repeat([self.hotkeys.keys[0]], m - len(keys)) + keys
      let i+=1
      let entry.num = i
      let entry.hotkey = join(keys, '')
    endfor
  endif

  "
  " Parse types
  "
  for entry in self.entries
    let entry.active = self.types[entry.type].active
  endfor

  "
  " Refresh if wanted
  "
  if a:force && self.is_open()
    call self.refresh()
  endif

  return self.entries
endfunction

" }}}1

"
" Creating, refreshing and filling the buffer
"
function! s:toc.create() abort dict " {{{1
  let l:bufnr = bufnr('')
  let l:winid = win_getid()
  let l:vimtex = get(b:, 'vimtex', {})

  if g:vimtex_toc_split_pos ==# 'full'
    silent execute 'edit' escape(self.name, ' ')
  else
    if g:vimtex_toc_resize
      silent exe 'set columns +=' . g:vimtex_toc_split_width
    endif
    silent execute
          \ g:vimtex_toc_split_pos g:vimtex_toc_split_width
          \ 'new' escape(self.name, ' ')
  endif

  let self.prev_bufnr = l:bufnr
  let self.prev_winid = l:winid
  let b:toc = self
  let b:vimtex = l:vimtex

  setlocal bufhidden=wipe
  setlocal buftype=nofile
  setlocal concealcursor=nvic
  setlocal conceallevel=2
  setlocal cursorline
  setlocal nobuflisted
  setlocal nolist
  setlocal nospell
  setlocal noswapfile
  setlocal nowrap
  setlocal tabstop=8

  if g:vimtex_toc_hide_line_numbers
    setlocal nonumber
    setlocal norelativenumber
  endif

  call self.refresh()
  call self.set_syntax()

  if g:vimtex_toc_fold
    let self.foldexpr = function('s:foldexpr')
    let self.foldtext  = function('s:foldtext')
    setlocal foldmethod=expr
    setlocal foldexpr=b:toc.foldexpr(v:lnum)
    setlocal foldtext=b:toc.foldtext()
    let &l:foldlevel = get(self, 'fold_level', g:vimtex_toc_fold_level_start)
  endif

  nnoremap <silent><nowait><buffer><expr> gg b:toc.show_help ? 'gg}j' : 'gg'
  nnoremap <silent><nowait><buffer> <esc>OA k
  nnoremap <silent><nowait><buffer> <esc>OB j
  nnoremap <silent><nowait><buffer> <esc>OC k
  nnoremap <silent><nowait><buffer> <esc>OD j
  nnoremap <silent><nowait><buffer> q             :call b:toc.close()<cr>
  nnoremap <silent><nowait><buffer> <esc>         :call b:toc.close()<cr>
  nnoremap <silent><nowait><buffer> <space>       :call b:toc.activate_current(0)<cr>
  nnoremap <silent><nowait><buffer> <2-leftmouse> :call b:toc.activate_current(0)<cr>
  nnoremap <silent><nowait><buffer> <cr>          :call b:toc.activate_current(1)<cr>
  nnoremap <buffer><nowait><silent> h             :call b:toc.toggle_help()<cr>
  nnoremap <buffer><nowait><silent> f             :call b:toc.filter()<cr>
  nnoremap <buffer><nowait><silent> F             :call b:toc.clear_filter()<cr>
  nnoremap <buffer><nowait><silent> s             :call b:toc.toggle_numbers()<cr>
  nnoremap <buffer><nowait><silent> t             :call b:toc.toggle_sorted_todos()<cr>
  nnoremap <buffer><nowait><silent> r             :call b:toc.get_entries(1)<cr>
  nnoremap <buffer><nowait><silent> -             :call b:toc.decrease_depth()<cr>
  nnoremap <buffer><nowait><silent> +             :call b:toc.increase_depth()<cr>

  for [type, cfg] in items(self.types)
    execute printf(
          \ 'nnoremap <buffer><nowait><silent> %s'
          \ . ' :call b:toc.toggle_type(''%s'')<cr>',
          \ cfg.key, type)
  endfor

  if self.hotkeys.enabled
    for entry in self.entries
      execute printf(
            \ 'nnoremap <buffer><nowait><silent> %s%s'
            \ . ' :call b:toc.activate_hotkey(''%s'')<cr>',
            \ self.hotkeys.leader, entry.hotkey, entry.hotkey)
    endfor
  endif

  " Jump to closest index
  call vimtex#pos#set_cursor(self.get_closest_index())
endfunction

" }}}1
function! s:toc.refresh() abort dict " {{{1
  let l:toc_winnr = bufwinnr(bufnr(self.name))
  let l:buf_winnr = bufwinnr(bufnr(''))

  if l:toc_winnr < 0
    return
  elseif l:buf_winnr != l:toc_winnr
    silent execute l:toc_winnr . 'wincmd w'
  endif

  call self.position_save()
  setlocal modifiable
  silent %delete

  call self.print_help()
  call self.print_entries()

  0delete _
  setlocal nomodifiable
  call self.position_restore()

  if l:buf_winnr != l:toc_winnr
    silent execute l:buf_winnr . 'wincmd w'
  endif
endfunction

" }}}1
function! s:toc.set_syntax() abort dict "{{{1
  syntax clear

  if self.show_help
    execute 'syntax match VimtexTocHelp'
          \ '/^\%<' . self.help_nlines . 'l.*/'
          \ 'contains=VimtexTocHelpKey,VimtexTocHelpLayerOn,VimtexTocHelpLayerOff'

    syntax match VimtexTocHelpKey /<\S*>/ contained
    syntax match VimtexTocHelpKey /^\s*[-+<>a-zA-Z\/]\+\ze\s/ contained
          \ contains=VimtexTocHelpKeySeparator
    syntax match VimtexTocHelpKeySeparator /\// contained

    syntax match VimtexTocHelpLayerOn /\w\++/ contained
          \ contains=VimtexTocHelpConceal
    syntax match VimtexTocHelpLayerOff /\w\+-/ contained
          \ contains=VimtexTocHelpConceal
    syntax match VimtexTocHelpConceal /[+-]/ contained conceal

    highlight link VimtexTocHelpKeySeparator VimtexTocHelp
  endif

  syntax match VimtexTocNum /\v^(([A-Z]+>|\d+)(\.\d+)*)?\s*/ contained
  syntax match VimtexTocTodo /\s\zsTODO: / contained
  syntax match VimtexTocHotkey /\[[^]]\+\]/ contained
  syntax match VimtexTocTag
        \ /^\[.\]/ contained

  syntax match VimtexTocSec0 /^.*0$/ contains=@VimtexTocStuff
  syntax match VimtexTocSec1 /^.*1$/ contains=@VimtexTocStuff
  syntax match VimtexTocSec2 /^.*2$/ contains=@VimtexTocStuff
  syntax match VimtexTocSec3 /^.*3$/ contains=@VimtexTocStuff
  syntax match VimtexTocSec4 /^.*4$/ contains=@VimtexTocStuff

  syntax cluster VimtexTocStuff
        \ contains=VimtexTocNum,VimtexTocTag,VimtexTocHotkey,VimtexTocTodo,@Tex

  syntax match VimtexLabelsChap /^chap:.*$/ contains=@Tex
  syntax match VimtexLabelsEq   /^eq:.*$/   contains=@Tex
  syntax match VimtexLabelsFig  /^fig:.*$/  contains=@Tex
  syntax match VimtexLabelsSec  /^sec:.*$/  contains=@Tex
  syntax match VimtexLabelsTab  /^tab:.*$/  contains=@Tex
endfunction

" }}}1

"
" Print the TOC entries
"
function! s:toc.print_help() abort dict " {{{1
  let self.help_nlines = 0
  if !self.show_help | return | endif

  let l:layer_title = 'Layers:  '
  let l:layer_keys =  '         '
  for [type, cfg] in items(self.types)
    let l:layer_title .= printf('%-10s', type . (cfg.active ? '+' : '-'))
    let l:layer_keys .= printf('%-9s', cfg.key)
  endfor

  let help_text = [
        \ '<Esc>/q  Close',
        \ '<Space>  Jump',
        \ '<Enter>  Jump and close',
        \ '      r  Refresh',
        \ '      s  Hide numbering',
        \ '      h  Toggle help text',
        \ '      t  Toggle sorted TODOs',
        \ '    -/+  Decrease/increase g:vimtex_toc_tocdepth',
        \ '    f/F  Apply/clear filter',
        \ '',
        \ l:layer_title,
        \ l:layer_keys,
        \]

  call append('$', help_text)
  call append('$', '')

  let self.help_nlines += len(help_text) + 1
endfunction

" }}}1
function! s:toc.print_entries() abort dict " {{{1
  let self.number_width = max([0, 2*(self.tocdepth + 2)])
  let self.number_format = '%-' . self.number_width . 's'

  for entry in self.entries
    if get(entry, 'active', 1) && !get(entry, 'hidden')
      call self.print_entry(entry)
    endif
  endfor
endfunction

" }}}1
function! s:toc.print_entry(entry) abort dict " {{{1
  let output = ''
  if self.show_numbers
    let number = a:entry.level >= self.tocdepth + 2 ? ''
          \ : strpart(self.print_number(a:entry.number),
          \           0, self.number_width - 1)
    let output .= printf(self.number_format, number)
  endif

  if self.hotkeys.enabled
    let output .= printf('[%S] ', a:entry.hotkey)
  endif

  let output .= printf('%-140S%s', a:entry.title, a:entry.level)

  call append('$', output)
endfunction

" }}}1
function! s:toc.print_number(number) abort dict " {{{1
  if empty(a:number) | return '' | endif
  if type(a:number) == type('') | return a:number | endif

  if get(a:number, 'part_toggle')
    return s:int_to_roman(a:number.part)
  endif

  let number = [
        \ a:number.chapter,
        \ a:number.section,
        \ a:number.subsection,
        \ a:number.subsubsection,
        \ a:number.subsubsubsection,
        \ ]

  " Remove unused parts
  while len(number) > 0 && number[0] == 0
    call remove(number, 0)
  endwhile
  while len(number) > 0 && number[-1] == 0
    call remove(number, -1)
  endwhile

  " Change numbering in frontmatter, appendix, and backmatter
  if self.topmatters > 1
        \ && (a:number.frontmatter || a:number.backmatter)
    return ''
  elseif a:number.appendix
    let number[0] = nr2char(number[0] + 64)
  endif

  return join(number, '.')
endfunction

" }}}1

"
" Interactions with TOC buffer/window
"
function! s:toc.activate_current(close_after) abort dict "{{{1
  let n = vimtex#pos#get_cursor_line() - 1
  if n < self.help_nlines | return {} | endif

  let l:count = 0
  for l:entry in self.entries
    if get(l:entry, 'active', 1) && !get(l:entry, 'hidden')
      if l:count == n - self.help_nlines
        return self.activate_entry(l:entry, a:close_after)
      endif
      let l:count += 1
    endif
  endfor

  return {}
endfunction

" }}}1
function! s:toc.activate_hotkey(key) abort dict "{{{1
  for entry in self.entries
    if entry.hotkey ==# a:key
      return self.activate_entry(entry, 1)
    endif
  endfor

  return {}
endfunction

" }}}1
function! s:toc.activate_entry(entry, close_after) abort dict "{{{1
  let self.prev_index = vimtex#pos#get_cursor_line()
  let l:vimtex_main = get(b:vimtex, 'tex', '')

  " Save toc winnr info for later use
  let toc_winnr = winnr()

  " Return to calling window
  call win_gotoid(self.prev_winid)

  " Get buffer number, add buffer if necessary
  let bnr = bufnr(a:entry.file)
  if bnr == -1
    execute 'badd ' . fnameescape(a:entry.file)
    let bnr = bufnr(a:entry.file)
  endif

  " Set bufferopen command
  "   The point here is to use existing open buffer if the user has turned on
  "   the &switchbuf option to either 'useopen' or 'usetab'
  let cmd = 'buffer! '
  if &switchbuf =~# 'usetab'
    for i in range(tabpagenr('$'))
      if index(tabpagebuflist(i + 1), bnr) >= 0
        let cmd = 'sbuffer! '
        break
      endif
    endfor
  elseif &switchbuf =~# 'useopen'
    if bufwinnr(bnr) > 0
      let cmd = 'sbuffer! '
    endif
  endif

  " Open file buffer
  execute 'keepalt' cmd bnr

  " Go to entry line
  if has_key(a:entry, 'line')
    call vimtex#pos#set_cursor(a:entry.line, 0)
  endif

  " If relevant, enable vimtex stuff
  if get(a:entry, 'link', 0) && !empty(l:vimtex_main)
    let b:vimtex_main = l:vimtex_main
    call vimtex#init()
  endif

  " Ensure folds are opened
  normal! zv

  " Keep or close toc window (based on options)
  if a:close_after && g:vimtex_toc_split_pos !=# 'full'
    call self.close()
  else
    " Return to toc window
    execute toc_winnr . 'wincmd w'
  endif
endfunction

" }}}1
function! s:toc.toggle_help() abort dict "{{{1
  let l:pos = vimtex#pos#get_cursor()
  if self.show_help
    let l:pos[1] -= self.help_nlines
    call vimtex#pos#set_cursor(l:pos)
  endif

  let self.show_help = self.show_help ? 0 : 1
  call self.refresh()
  call self.set_syntax()

  if self.show_help
    let l:pos[1] += self.help_nlines
    call vimtex#pos#set_cursor(l:pos)
  endif
endfunction

" }}}1
function! s:toc.toggle_numbers() abort dict "{{{1
  let self.show_numbers = self.show_numbers ? 0 : 1
  call self.refresh()
endfunction

" }}}1
function! s:toc.toggle_sorted_todos() abort dict "{{{1
  let self.todo_sorted = self.todo_sorted ? 0 : 1
  call self.get_entries(1)
  call vimtex#pos#set_cursor(self.get_closest_index())
endfunction

" }}}1
function! s:toc.toggle_type(type) abort dict "{{{1
  let self.types[a:type].active = !self.types[a:type].active
  for entry in self.entries
    if entry.type ==# a:type
      let entry.active = self.types[a:type].active
    endif
  endfor
  call self.refresh()
endfunction

" }}}1
function! s:toc.decrease_depth() abort dict "{{{1
  let self.tocdepth = max([self.tocdepth - 1, -2])
  call self.refresh()
endfunction

" }}}1
function! s:toc.increase_depth() abort dict "{{{1
  let self.tocdepth = min([self.tocdepth + 1, 5])
  call self.refresh()
endfunction

" }}}1
function! s:toc.filter() dict "{{{1
  let re_filter = input('filter entry title by: ')
  for entry in self.entries
    let entry.hidden = get(entry, 'hidden') || entry.title !~# re_filter
  endfor
  call self.refresh()
endfunction

" }}}1
function! s:toc.clear_filter() dict "{{{1
  for entry in self.entries
    let entry.hidden = 0
  endfor
  call self.refresh()
endfunction

" }}}1

"
" Utility functions
"
function! s:toc.get_closest_index() abort dict " {{{1
  let l:calling_rank = 0
  let l:not_found = 1
  for [l:file, l:lnum, l:line] in vimtex#parser#tex(b:vimtex.tex)
    let l:calling_rank += 1
    if l:file ==# self.calling_file && l:lnum >= self.calling_line
      let l:not_found = 0
      break
    endif
  endfor

  if l:not_found
    return [0, get(self, 'prev_index', self.help_nlines + 1), 0, 0]
  endif

  let l:index = 0
  let l:dist = 0
  let l:closest_index = 1
  let l:closest_dist = 10000
  for l:entry in self.entries
    if get(l:entry, 'active', 1) && !get(l:entry, 'hidden')
      let l:index += 1
      let l:dist = l:calling_rank - entry.rank

      if l:dist >= 0 && l:dist < l:closest_dist
        let l:closest_dist = l:dist
        let l:closest_index = l:index
      endif
    endif
  endfor

  return [0, l:closest_index + self.help_nlines, 0, 0]
endfunction

" }}}1
function! s:toc.position_save() abort dict " {{{1
  let self.position = vimtex#pos#get_cursor()
endfunction

" }}}1
function! s:toc.position_restore() abort dict " {{{1
  if self.position[1] <= self.help_nlines
    let self.position[1] = self.help_nlines + 1
  endif
  call vimtex#pos#set_cursor(self.position)
endfunction

" }}}1


function! s:foldexpr(lnum) abort " {{{1
  let pline = getline(a:lnum - 1)
  let cline = getline(a:lnum)
  let nline = getline(a:lnum + 1)
  let l:pn = matchstr(pline, '\d$')
  let l:cn = matchstr(cline, '\d$')
  let l:nn = matchstr(nline, '\d$')

  " Don't fold options
  if cline =~# '^\s*$'
    return 0
  endif

  if l:nn > l:cn
    return '>' . l:nn
  endif

  if l:cn < l:pn
    return l:cn
  endif

  return '='
endfunction

" }}}1
function! s:foldtext() abort " {{{1
  let l:line = getline(v:foldstart)

  if b:toc.todo_sorted && l:line =~# 'TODO:'
    return substitute(l:line, 'TODO\zs:.*', 's', '')
  else
    return l:line
  endif
endfunction

" }}}1

function! s:int_to_roman(number) " {{{1
  let l:number = a:number
  let l:result = ''
  for [l:val, l:romn] in [
        \ ['1000', 'M'],
        \ ['900', 'CM'],
        \ ['500', 'D'],
        \ ['400', 'CD' ],
        \ ['100', 'C'],
        \ ['90', 'XC'],
        \ ['50', 'L'],
        \ ['40', 'XL'],
        \ ['10', 'X'],
        \ ['9', 'IX'],
        \ ['5', 'V'],
        \ ['4', 'IV'],
        \ ['1', 'I'],
        \]
    while l:number >= l:val
      let l:number -= l:val
      let l:result .= l:romn
    endwhile
  endfor

  return l:result
endfunction

" }}}1
function! s:base(n, k) " {{{1
  if a:n < a:k
    return [a:n]
  else
    return add(s:base(a:n/a:k, a:k), a:n % a:k)
  endif
endfunction

" }}}1
