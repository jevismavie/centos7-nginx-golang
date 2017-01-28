FROM centos:7.3.1611

# Build args
ARG goversion="1.7.4"
ENV GO_BINARY go${goversion}.linux-amd64.tar.gz
ARG repos="github.com"
ENV SRCDIR /root/go/src/${repos}

# Install systemd
RUN \
  exec >& /root/build-systemd.log ;\
  set -eux ;\
  yum swap -y fakesystemd systemd initscripts epel-release;\
  yum -y install vim wget ;\
  yum clean all ;
RUN wget https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-7 ;
RUN rpm --import RPM-GPG-KEY-EPEL-7 ;

# Timezone
RUN \
  unlink /etc/localtime ;\
  ln -s /usr/share/zoneinfo/Japan /etc/localtime ;\
  localedef -f UTF-8 -i ja_JP ja_JP.UTF-8 ;

# Environment
ENV F1 /root/.bashrc
RUN \
  echo "export HOME=/root"        > ${F1} ;\
  echo "export EDITOR=vim"       >> ${F1} ;\
  echo "export LANG=ja_JP.UTF-8" >> ${F1} ;\
  echo "alias ls='ls --color'"   >> ${F1} ;\
  echo "alias vi='vim -p'"       >> ${F1} ;\
  echo "alias vim='vim -p'"      >> ${F1}
ENV F2 /root/.gitconfig
RUN \
  echo "[user]"                                > ${F2} ;\
  echo "  email = root@localhost.localdomain" >> ${F2} ;\
  echo "  name = root"                        >> ${F2} ;\
  echo "[info] done."

# Root password
RUN yum -y install passwd;
RUN echo 'root:root' | chpasswd ;

# Install nginx (latest stable ver 1.10.2)
RUN wget http://nginx.org/packages/keys/nginx_signing.key ;
RUN rpm --import nginx_signing.key ;

ENV F3 /etc/yum.repos.d/nginx.repo
RUN \
  echo '[nginx]'                                                > ${F3} ;\
  echo 'name=nginx repo'                                       >> ${F3} ;\
  echo 'baseurl=http://nginx.org/packages/centos/7/$basearch/' >> ${F3} ;\
  echo 'gpgcheck=1'                                            >> ${F3} ;\
  echo 'enabled=1'                                             >> ${F3} ;
RUN yum -y --enablerepo=nginx install nginx && yum clean all;

# Bind directory
RUN mkdir -p /usr/local/go
RUN mkdir -p /root/go/{bin,src}
RUN mkdir -p /root/tmp

# Install golang
ENV TMPDIR /root/tmp
RUN \
  curl -fLo ${TMPDIR}/${GO_BINARY} --create-dirs https://storage.googleapis.com/golang/${GO_BINARY}
WORKDIR ${TMPDIR}
RUN \
  tar -C /usr/local -zxvf ${GO_BINARY} \
  && chmod -R 777 /usr/local/go \
  && rm -f ${GO_BINARY}

# Install glide
ENV GOROOT /usr/local/go
ENV GOPATH /root/go
RUN \
  echo '# Golang'                                  >> ${F1} ;\
  echo 'export GOROOT='${GOROOT}                   >> ${F1} ;\
  echo 'export GOPATH='${GOPATH}                   >> ${F1} ;\
  echo 'export PATH=$PATH:$GOROOT/bin:$GOPATH/bin' >> ${F1} ;\
  echo 'curl https://glide.sh/get | bash'          >> ${F1} ;
RUN \
  source ${F1} && cat ${F1} |sed "s/curl.*//g" > work && mv work ${F1}
RUN yum install -y git && yum clean all
RUN yum install -y which && yum clean all

# Install vim / vim-plug
RUN yum -y install vim && yum clean all
RUN curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
ENV F4 /root/.vimrc
RUN \
  echo "filetype off " > ${F4} ;\
  echo "filetype plugin indent off " >> ${F4} ;\
  echo "set rtp+=$GOROOT/misc/vim " >> ${F4} ;\
  echo "filetype plugin indent on " >> ${F4} ;\
  echo "syntax on " >> ${F4} ;\
  echo "autocmd FileType go autocmd BufWritePre  Fmt " >> ${F4} ;\
  echo "set rtp+=$GOPATH/src/github.com/nsf/gocode/vim " >> ${F4} ;\
  echo "set rtp+=$GOPATH/src/github.com/github.com/golang/lint/golint " >> ${F4} ;\
  echo "set completeopt=menu,preview " >> ${F4} ;\
  echo "call plug#begin('~/.vim/plugged') " >> ${F4} ;\
  echo "Plug 'vim-scripts/sudo.vim' " >> ${F4} ;\
  echo "Plug 'sjl/badwolf' " >> ${F4} ;\
  echo "Plug 'fatih/molokai' " >> ${F4} ;\
  echo "Plug 'scrooloose/syntastic' " >> ${F4} ;\
  echo "Plug 'scrooloose/nerdtree', { 'on':  'NERDTreeToggle' } " >> ${F4} ;\
  echo "Plug 'jistr/vim-nerdtree-tabs' " >> ${F4} ;\
  echo "Plug 'fatih/vim-go' " >> ${F4} ;\
  echo "Plug 'vim-jp/vim-go-extra' " >> ${F4} ;\
  echo "Plug 'stephpy/vim-yaml' " >> ${F4} ;\
  echo "Plug 'nsf/gocode', { 'rtp': 'vim', 'do': '~/.vim/plugged/gocode/vim/symlink.sh' } " >> ${F4} ;\
  echo "call plug#end() " >> ${F4} ;
RUN vim -c ':PlugInstall' -c ':qa' 1>/dev/null 2>&1
RUN \
  echo "syntax enable " >> ${F4} ;\
  echo "set background=dark " >> ${F4} ;\
  echo "colorscheme molokai " >> ${F4} ;\
  echo "set backspace=indent,eol,start " >> ${F4} ;\
  echo "set number " >> ${F4} ;\
  echo "exe \"set rtp+=\".globpath(\$GOPATH, \"src/github.com/nsf/gocode/vim\") " >> ${F4} ;\
  echo "function! ZenkakuSpace() " >> ${F4} ;\
  echo "    highlight ZenkakuSpace cterm=reverse ctermfg=DarkMagenta gui=reverse guifg=DarkMagenta " >> ${F4} ;\
  echo "endfunction " >> ${F4} ;\
  echo "if has('syntax') " >> ${F4} ;\
  echo "    augroup ZenkakuSpace " >> ${F4} ;\
  echo "        autocmd! " >> ${F4} ;\
  echo "        autocmd ColorScheme       * call ZenkakuSpace() " >> ${F4} ;\
  echo "        autocmd VimEnter,WinEnter * match ZenkakuSpace /　/ " >> ${F4} ;\
  echo "    augroup END " >> ${F4} ;\
  echo "    call ZenkakuSpace() " >> ${F4} ;\
  echo "endif " >> ${F4} ;\
  echo "autocmd FileType yml setlocal expandtab tabstop=2 shiftwidth=2 softtabstop=2 autoindent " >> ${F4} ;\
  echo "autocmd FileType go setlocal noexpandtab tabstop=4 shiftwidth=4 softtabstop=4 " >> ${F4} ;\
  echo "autocmd FileType go colorscheme badwolf " >> ${F4} ;\
  echo "autocmd FileType go :highlight goErr cterm=bold ctermfg=214 " >> ${F4} ;\
  echo "autocmd FileType go :match goErr /\<err\>/ " >> ${F4} ;\
  echo "let g:go_highlight_functions = 1 " >> ${F4} ;\
  echo "let g:go_highlight_methods = 1 " >> ${F4} ;\
  echo "let g:go_highlight_structs = 1 " >> ${F4} ;\
  echo "let g:go_highlight_operators = 1 " >> ${F4} ;\
  echo "let g:go_highlight_build_constraints = 1 " >> ${F4} ;\
  echo "let g:go_highlight_interfaces = 1 " >> ${F4} ;\
  echo "let g:go_bin_path = expand(\"$GOPATH/bin\") " >> ${F4} ;\
  echo "let g:go_play_open_browser = 0 " >> ${F4} ;\
  echo "let g:go_fmt_fail_silently = 1 " >> ${F4} ;\
  echo "let g:go_fmt_autosave = 1 " >> ${F4} ;\
  echo "let g:go_fmt_command = \"goimports\" " >> ${F4} ;\
  echo "let g:go_disable_autoinstall = 1 " >> ${F4} ;\
  echo "let g:airline#extensions#tabline#left_sep = ' ' " >> ${F4} ;\
  echo "let g:airline#extensions#tabline#left_alt_sep = '|' " >> ${F4} ;\
  echo "nmap <silent><C-e> :NERDTreeToggle<CR> " >> ${F4} ;\
  echo "nmap <Leader>n <plug>NERDTreeTabsToggle<CR> " >> ${F4} ;\
  echo "au FileType go nmap <Leader>i <Plug>(go-info) " >> ${F4} ;\
  echo "au FileType go nmap <Leader>gd <Plug>(go-doc) " >> ${F4} ;\
  echo "au FileType go nmap <Leader>gv <Plug>(go-doc-vertical) " >> ${F4} ;\
  echo "au FileType go nmap <leader>gb <Plug>(go-build) " >> ${F4} ;\
  echo "au FileType go nmap <leader>gt <Plug>(go-test) " >> ${F4} ;\
  echo "au FileType go nmap gd <Plug>(go-def) " >> ${F4} ;\
  echo "au FileType go nmap <Leader>ds <Plug>(go-def-split) " >> ${F4} ;\
  echo "au FileType go nmap <Leader>dv <Plug>(go-def-vertical) " >> ${F4} ;\
  echo "au FileType go nmap <Leader>dt <Plug>(go-def-tab) " >> ${F4} ;\
  echo "au FileType go nmap <Leader>gl :GoLint<CR> " >> ${F4} ;

# Create nginx index.html
RUN echo "Welcome to nginx!" > /usr/share/nginx/html/index.html

# Enable to service nginx
RUN rm -f /etc/systemd/system/multi-user.target.wants/nginx.service
RUN ln -s /usr/lib/systemd/system/nginx.service /etc/systemd/system/multi-user.target.wants/nginx.service

WORKDIR ${SRCDIR}

ENTRYPOINT ["tail", "-f", "/dev/null"]

EXPOSE 80
