import os
import functools
import platform
import pathlib
import zipfile
import io
import sys
import shutil
import re

$XONSH_HISTORY_SIZE = '1 gig'
$TOXENV = 'py'
$ABODE_USERNAME = 'jaraco@jaraco.com'
$PROJECTS_LIST_URL = 'https://www.dropbox.com/s/g16c8w9i7lg9dqn/projects.txt?dl=1'

$PATH.insert(0, '~/.local/bin')
$PATH.append('~/code/MestreLion/git-tools')
$PATH.append('~/code/gob/depot_tools')

aliases['git-id'] = 'git rev-parse --short HEAD'
aliases['gpo'] = 'git push --set-upstream origin @$(git rev-parse --abbrev-ref HEAD)'
aliases['gpj'] = 'git push --set-upstream jaraco @$(git rev-parse --abbrev-ref HEAD)'

aliases['hobgoblins'] = "git commit -a -m '👹 Feed the hobgoblins (delint).'"
aliases['fade-to-black'] = "git commit -a -m '⚫ Fade to black.'"
aliases['genuflect'] = "git commit -a -m '🧎‍♀️ Genuflect to the types.'"
aliases['toil-the-docs'] = "git commit -a -m '🚡 Toil the docs.'"

try:
	import jaraco.clipboard
except ImportError:
	print("Clipboard support unavailable")

# https://xon.sh/osx.html#path-helper
if platform.system() == 'Darwin':
	source-bash --seterrprevcmd "" /etc/profile

profile = os.path.expanduser('~/Dropbox/config/mac/profile')
if os.path.isfile(profile) and platform.system() != 'Windows':
	source-bash @(profile)

$PATH.add(pathlib.Path('~/.local/bin').expanduser(), front=True)

# allow for local settings in ~/.local/xonsh.d
for localf in pathlib.Path('~/.local/xonsh.d').expanduser().glob('*'):
	source @(localf)


import keyring

$PROMPT = '{env_name:{} }{cwd_base}{branch_color}{curr_branch: {}}{RESET} {BOLD_BLUE}{prompt_end}{RESET} '

def remove_mercurial_metadata():
	git rm .hg*
	git commit -m "Remove Mercurial metadata"

aliases['remove-mercurial-metadata'] = remove_mercurial_metadata


$VIRTUALENV_HOME = os.path.expanduser('~/.local/envs')


def git_push_new_branch():
	head = $(git rev-parse --abbrev-ref HEAD).rstrip()
	git push --set-upstream origin @(head)

aliases['gpo'] = git_push_new_branch


def git_prune_merged_branches():
	branches = [
		line.strip()
		for line in $(git branch --merged).splitlines()
		if '*' not in line
	]
	for branch in branches:
		git branch -d @(branch)


aliases['gpm'] = git_prune_merged_branches
aliases['gcan'] = 'git commit -a --amend --no-edit'

def get_oath(system, user):
	code = keyring.get_password(system, user).replace(' ', '')
	otp = $(oathtool @(code)).rstrip()
	jaraco.clipboard.copy(otp)


def add_mfa(alias, system, user):
	aliases[alias] = functools.partial(get_oath, system, user)

add_mfa('dropbox-mfa', 'Dropbox MFA', 'jaraco@jaraco.com')
add_mfa('microsoft-mfa', 'Microsoft MFA', 'jaraco@jaraco.com')
add_mfa('mongodb-mfa', 'MongoDB MFA', 'jaraco')
add_mfa('coinbase-mfa', 'Coinbase MFA', 'jaraco@jaraco.com')
add_mfa('amazon-mfa', 'Amazon MFA', 'jaraco@jaraco.com')
add_mfa('aws-root-mfa', 'Amazon AWS Root MFA', 'jaraco@jaraco.com')
add_mfa('aws-mfa', 'Amazon AWS MFA', 'jaraco')
add_mfa('github-mfa', 'GitHub MFA', 'jaraco')
add_mfa('cloudflare-cp-mfa', 'Cloudflare MFA', 'wk+cherrypy-cloudflare@sydorenko.org.ua')
add_mfa('pypi-mfa', 'PyPI MFA', 'jaraco')
add_mfa('gitlab-mfa', 'GitLab MFA', 'jaraco')
add_mfa('login-gov-mfa', 'Login.gov MFA', 'jaraco')
add_mfa('discord-mfa', 'Discord MFA', 'jaraco@jaraco.com')
add_mfa('mypath-mfa', 'mypath.pa.gov MFA', 'jaraco')
add_mfa('lc-mfa', 'LocalCryptos MFA', 'jaraco')
add_mfa('heroku-mfa', 'Heroku MFA', 'jaraco@jaraco.com')
add_mfa('global-shares-mfa', 'Global Shares Equity MFA', 'jaraco')
add_mfa('namecheap-mfa', 'Namecheap MFA', 'jaraco')
add_mfa('google-mfa', 'Google MFA', 'jaraco@jaraco.com')

aliases.update(gclip='pbcopy', pclip='pbpaste')

# workaround for https://bugs.python.org/issue22490
${...}.pop('__PYVENV_LAUNCHER__', None)


# disable traceback notice
$XONSH_SHOW_TRACEBACK = False


def get_repo_url():
	raw = $(git remote get-url --push origin).rstrip()
	return raw.replace('https://github.com/', '')


def switch_env(pw):
	"""
	Does the .travis.yml need the environment variable treatment?
	If so, wrap the password in the environment variable.

	https://github.com/pypa/warehouse/issues/6422#issuecomment-523355317
	"""
	uses_env = 'password:' not in pathlib.Path('.travis.yml').read_text()
	if not uses_env:
		print("Using simple password (without env)")
		return pw
	return 'TWINE_PASSWORD="' + pw + '"'

def gen_pypi_token():
	pw = switch_env($(keyring get https://upload.pypi.org/legacy/ __token__).rstrip())
	crypt_pw = $(echo @(pw) | travis encrypt -r @(get_repo_url())).rstrip().strip('"')
	jaraco.clipboard.copy(crypt_pw)

aliases['gen-pypi-token'] = gen_pypi_token


def install_pypi_token():
	$TWINE_PASSWORD=keyring.get_password('https://upload.pypi.org/legacy/', '__token__')
	assert $TWINE_PASSWORD
	travis env copy -r @(get_repo_url()) TWINE_PASSWORD

aliases['install-pypi-token'] = install_pypi_token


aliases['travis-login'] = 'travis login --github-token @(keyring.get_password("Github", "jaraco"))'


def install_tidelift_token():
	$TIDELIFT_TOKEN=keyring.get_password('https://api.tidelift.com/external-api/', 'jaraco')
	travis env copy -r @(get_repo_url()) TIDELIFT_TOKEN

aliases['install-tidelift-token'] = install_tidelift_token

def get_aws_pw(account_id):
	url = f'https://{account_id}.signin.aws.amazon.com/console'
	return keyring.get_password(url, $USER)


def docker_login():
	keyring get https://id.docker.com $USER | docker login --password-stdin --username $USER

aliases['docker-login'] = docker_login

def copy_public_key():
	key_file = pathlib.Path('~/.ssh/id_rsa.pub').expanduser()
	with key_file.open() as f:
		jaraco.clipboard.copy_text(f.read())

aliases['copy-public-key'] = copy_public_key


class UnzipStream:
	def __call__(self, args, stdin):
		self.stdin = stdin
		self.run(*args)

	def run(self, dest='.'):
		data = io.BytesIO(self.stdin.buffer.read())
		z = zipfile.ZipFile(data)
		z.extractall(dest)

aliases['unzip-stream'] = UnzipStream()


def take(name):
	mkdir -p @(name)
	cd @(name)

aliases['take'] = lambda args: take(*args)

xontrib load vox

def _enable_aws():
	$AWS_DEFAULT_OUTPUT='json'
	$AWS_DEFAULT_REGION='us-east-1'
	$AWS_ACCESS_KEY_ID='AKIAI67HHYIIHERSWNAQ'
	$AWS_SECRET_ACCESS_KEY=keyring.get_password('AWS', $AWS_ACCESS_KEY_ID)

aliases['enable-aws'] = _enable_aws


def enable_libssl():
	# Make OpenSSL generally available.
	# See https://github.com/pyca/cryptography/issues/2350
	# and consider
	# https://github.com/phusion/passenger/issues/1630#issuecomment-147527656

	# Not run by default because pyyaml fails to build in
	# a virtualenv with those vars set
	enable_lib('openssl')


def enable_lib(name):
	prefix = $(brew --prefix @(name)).strip()
	$LDFLAGS = f'-L{prefix}/lib'
	$CFLAGS = f'-I{prefix}/include'


def _charging():
	while True:
		print(charge_status(), end='\r')


def charge_status():
	import json
	data = $(system_profiler SPPowerDataType -json)
	info = json.loads(data)
	amps = info['SPPowerDataType'][0]['sppower_current_amperage']
	dir = 'discharging' if amps < 0 else 'charging'
	charge_msg = f'battery is {dir} at a rate of {abs(amps)}mA'
	return charge_msg if amps else 'battery is fully charged'


aliases['charging'] = _charging


def az_delete(args):
	name, = args
	query = f'.value[] | select(.name=="{name}").id'
	id = $(az devops project list | jq -r @(query)).strip()
	az devops project delete --yes --id @(id)


aliases['az-delete'] = az_delete


def apv_delete(args):
	name, = args
	query = f'.[] | select(.name=="{name}").slug'
	auth = 'Bearer ' + keyring.get_password('https://ci.appveyor.com/', $USER)
	id = $(http https://ci.appveyor.com/api/account/$USER/projects Authorization:@(auth) | jq -r @(query)).strip()
	http delete https://ci.appveyor.com/api/projects/$USER/@(id) 'Content-Type: application/json' Authorization:@(auth)


aliases['apv-delete'] = apv_delete


def move_prs(repo):
	import json
	prs = json.loads($(gh api /repos/@(repo)/pulls?base=master))
	nums = [pr['number'] for pr in prs]
	for pr_num in nums:
		gh api -X PATCH /repos/@(repo)/pulls/@(pr_num) -F base=main


def move_rtd(repo):
	org, _, project = repo.partition('/')
	rtd_name = project.replace('.', '').replace('_', '-')
	rp = pathlib.Path('README.rst')
	readme = rp.read_text() if rp.is_file() else ''
	if f'{rtd_name}.readthedocs' not in readme:
		return
	auth = 'Token ' + keyring.get_password('https://api.readthedocs.org/', 'token')
	http patch https://readthedocs.org/api/v3/projects/@(rtd_name)/ Authorization:@(auth) default_branch=main


def create_rtd(args):
	import posixpath
	path, = args
	url = f'https://github.com/{path}'
	name = posixpath.basename(path)
	token = keyring.get_password('https://api.readthedocs.org/', 'token')
	auth = f'Token {token}'
	http https://readthedocs.org/api/v3/projects/ Authorization:@(auth) f'repository[url]={url}' 'repository[type]=git' name=@(name)


aliases['create-rtd'] = create_rtd


def retire_master():
	git checkout master
	git pull
	git checkout -b main
	gpo
	repo = get_repo_url()
	move_prs(repo)
	move_rtd(repo)
	gh api -X PATCH /repos/@(repo) -F default_branch=main
	git push origin :master
	git branch -d master
	# more to do?
	# https://www.hanselman.com/blog/easily-rename-your-git-default-branch-from-master-to-main
	git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main

aliases['retire-master'] = retire_master


def docker_windows():
	pushd ~/p/windows-docker-machine
	vagrant up 2019-box
	popd
	$DOCKER_CONTEXT = '2019-box'
	# docker context use 2019-box


def docker_linux():
	pushd ~/p/windows-docker-machine
	vagrant halt 2019-box
	popd
	del $DOCKER_CONTEXT
	# docker context use default


aliases['docker-windows'] = docker_windows
aliases['docker-linux'] = docker_linux
aliases['eject'] = 'drutil eject'


def connect_share(name, host='tanuki.local'):
	username = $USER
	mount = f'/Volumes/{name}'
	sudo mkdir @(mount)
	sudo chown $USER @(mount)
	password = keyring.get_password(host, username)
	url = f'//{username}:{password}@{host}/{name}'
	mount_smbfs -o quarantine @(url) @(mount)


def send_sms(from_to, message):
	from_, _, to = from_to.rpartition(':')
	from_ = from_ or '+12028580120'
	account = 'AC00c9739a1539392c4a97f5dc3f5d94c2'
	token = keyring.get_password('twilio', account)
	auth = f'{account}:{token}'
	url = f'https://api.twilio.com/2010-04-01/Accounts/{account}/Messages.json'
	http -q -f -a @(auth) @(url) From=@(from_) To=@(to) Body=@(message)


aliases['send-sms'] = lambda args: send_sms(*args)


def git_remote():
	local = $(git name-rev --name-only HEAD).strip()
	key = f'branch.{local}.remote'
	git config @(key)

aliases['git-remote'] = git_remote


def _mongo_jaraco():
	mongo mongodb.jaraco.com/admin -u jaraco -p @($(keyring get mongodb.jaraco.com/admin jaraco).strip())


aliases['mongo-jaraco'] = _mongo_jaraco


def _teslacam_sync():
	# connect_share('archive')
	# rsync -rt --progress --info progress2 /Volumes/MEGAMI/TeslaCam /Volumes/archive
	rsync -rt --progress --info progress2 /Volumes/MEGAMI/TeslaCam tanuki.local:/shares/archive
	if _.rtn == 0:
		rm -r /Volumes/MEGAMI/TeslaCam/*


aliases['teslacam-sync'] = _teslacam_sync


# workaround https://github.com/xonsh/xonsh/issues/4409
__import__('warnings').filterwarnings('ignore', 'There is no current event loop', DeprecationWarning, 'prompt_toolkit.application.application')


aliases['firefox-liam'] = 'open -n -a Firefox.app --args --no-remote -P Liam'


if !(which brew):
# Workaround for https://github.com/xonsh/xonsh/issues/4737
	$BASH_COMPLETIONS.append($(brew --prefix).strip() + '/share/bash-completion/bash_completion')


aliases['charm'] = 'open -na "PyCharm.app"'


def work_on(args):
	name, = args
	matches = gf`~/code/*/*{name}`
	by_len = sorted(matches, key=len)
	cd @(by_len[0])
aliases['work-on'] = work_on


# workaround for https://github.com/xonsh/xonsh/issues/5173
__import__('xonsh.xonfig').xonfig.WELCOME_MSG = []


def re_log(args):
	"""
	Reflect the recent commit message in a news fragment.
	"""
	try:
		type, = args
	except ValueError:
		type = 'feature'
	msg = $(git log -1 --oneline --format=%s)
	(descr, *rest) = msg.splitlines()
	try:
		number = re.search(r'#\d+', msg).group(0)
	except AttributeError:
		number = '+'
	towncrier create -c @(descr.strip().rstrip('.') + '.') @(number).@(type).rst
	git add newsfragments
	git commit --amend --no-edit

aliases['re-log'] = re_log
