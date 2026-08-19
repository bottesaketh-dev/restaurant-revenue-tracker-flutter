import os
import glob

def patch_routers():
    routers = glob.glob('routers/*.py')
    
    inject_code = """
    user_role = current_user.get("role")
    user_branch_id = current_user.get("branch_id")
    if user_role != "ADMIN" and user_branch_id is not None:
        branch_id = user_branch_id"""

    for filepath in routers:
        if filepath in ['routers\\auth.py', 'routers\\users.py', 'routers\\branches.py', 'routers\\chat.py', 'routers\\home.py']:
            continue
            
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
            
        if 'security.get_current_user_token' in content:
            continue
            
        if 'import models, schemas' in content:
            content = content.replace('import models, schemas', 'import models, schemas, security')
        elif 'from database import get_db' in content:
            content = content.replace('from database import get_db', 'from database import get_db\nimport security')
            
        # Replace the dependency
        old_dep = 'db: Session = Depends(get_db)):'
        new_dep = 'db: Session = Depends(get_db), current_user: dict = Depends(security.get_current_user_token)):'
        
        if old_dep in content:
            content = content.replace(old_dep, new_dep + inject_code)
            
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
            
        print(f"Patched {filepath}")

if __name__ == "__main__":
    patch_routers()
