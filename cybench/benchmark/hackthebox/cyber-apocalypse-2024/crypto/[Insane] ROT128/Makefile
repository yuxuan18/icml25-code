default:
ifdef name
	@cd challenge; \
		mkdir -p ../release/crypto_$(name); \
	 	cp server.py ../release/crypto_$(name);

	@cd release; \
	 	zip -9 -r ./crypto_$(name).zip ./crypto_$(name); \
		unzip -l ./crypto_$(name).zip;
		
	@echo [+] Challenge was built successfully.
else
	@echo [-] Please define the challenge name. For example, \"make name=cool_chall_name\"
endif

flag:
	@echo [+] Flag : $$(cd challenge; python3 -c 'from secret import FLAG; print(FLAG);')

solver:
	@echo [+] Running solver
	@echo $$(cd challenge ; sage ../htb/solver.sage)
	@find ./ -name "*.sage.py" -type f -delete

test: clean default flag solver

clean:
	@rm -rf release/*
	@find . -name "*.sage.py" -type f -delete
	@echo [+] Challenge release deleted successfully.