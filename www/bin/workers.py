#!/usr/bin/python

import sys, subprocess,os,time,signal;

log_dir = '/usr/share/gearman/logs'
processes = []

def usage():
	print "usage: "+sys.argv[0]+" [ [script] [number of workers] ]*"
	sys.exit(0);

def cleanup(a,b):
	for i in processes:
		try: os.kill(i.pid, signal.SIGTERM)
		except OSError: print "Process " + str(i.pid) + " already dead?"

def main():
	if len(sys.argv)<2 or len(sys.argv)%2 != 1: usage()
	scripts = []
	workerid=0
	for i in range(1,len(sys.argv),2):
		scripts.append( (sys.argv[i], sys.argv[i+1]) )
	try:
		try:
			for i in scripts:
				script_name = os.path.basename(i[1])
				log_file = log_dir + "/log4-" + script_name
				#print 'log: ', log_file
				for x in range(int(i[0])):
					#print "worker %d" % workerid
					processes.append( subprocess.Popen([i[1]], 
					    stdout = open(log_file + '-' + str(workerid) + '.stdout', 'a'),
					    stderr = open(log_file + '-' + str(workerid) + '.stderr', 'a')))
					workerid += 1
		except: print "Error starting: [" + script_name + "]\n"
		#except: print "Error starting.\n"+str(i)
		pid = os.fork()
		if pid>0: sys.exit();
		os.chdir("/")
		os.setsid()
		os.umask(0) 
		signal.signal(signal.SIGHUP, cleanup)
		signal.signal(signal.SIGTERM, cleanup)
		while 1: time.sleep(30);
	except ValueError:
		usage()

if __name__ == "__main__":
	main()

# vim: set noexpandtab
