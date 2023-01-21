documentation:
	@jazzy \
	    --hide-documentation-coverage \
	    --min-acl private \
	    -x -workspace,Spe2ee.xcworkspace,-scheme,Spe2ee
	@rm -rf ./build
	@undocument sed -i '' -e 's/Undocumented/ /g' $(find ./docs -type f)
#	@undoc find ./docs/ -type f -exec sed -i '' -e 's/Undocumented/ /g' {} \;
	